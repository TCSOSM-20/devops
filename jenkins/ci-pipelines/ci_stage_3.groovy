/* Copyright 2017 Sandvine
 *
 * All Rights Reserved.
 * 
 *   Licensed under the Apache License, Version 2.0 (the "License"); you may
 *   not use this file except in compliance with the License. You may obtain
 *   a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 *   WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 *   License for the specific language governing permissions and limitations
 *   under the License.
 */
 
/* Change log:
 * 1. Bug 745 : Jayant Madavi, Mrityunjay Yadav : JM00553988@techmahindra.com : 23-july-2019 : Improvement to the code, typically we have 2 *    or more branches whose build gets triggered, ex master & release branch, the previous code was removing any/all docker. 
 *	  Now removing previous docker of the same branch, so that the other branch failed docker should not be removed. It also 
 *    acts as clean-up for previous docker remove failure.
 */
properties([
    parameters([
        string(defaultValue: env.GERRIT_BRANCH, description: '', name: 'GERRIT_BRANCH'),
        string(defaultValue: 'system', description: '', name: 'NODE'),
        string(defaultValue: '', description: '', name: 'BUILD_FROM_SOURCE'),
        string(defaultValue: 'unstable', description: '', name: 'REPO_DISTRO'),
        string(defaultValue: '', description: '', name: 'COMMIT_ID'),
        string(defaultValue: '-stage_2', description: '', name: 'UPSTREAM_SUFFIX'),
        string(defaultValue: 'pubkey.asc', description: '', name: 'REPO_KEY_NAME'),
        string(defaultValue: 'release', description: '', name: 'RELEASE'),
        string(defaultValue: '', description: '', name: 'UPSTREAM_JOB_NAME'),
        string(defaultValue: '', description: '', name: 'UPSTREAM_JOB_NUMBER'),
        string(defaultValue: '', description: '', name: 'UPSTREAM_JOB_NUMBER'),
        string(defaultValue: 'OSMETSI', description: '', name: 'GPG_KEY_NAME'),
        string(defaultValue: 'artifactory-osm', description: '', name: 'ARTIFACTORY_SERVER'),
        string(defaultValue: 'osm-stage_4', description: '', name: 'DOWNSTREAM_STAGE_NAME'),
        string(defaultValue: '6.0.2rc1', description: '', name: 'DOCKER_TAG'),
        booleanParam(defaultValue: true, description: '', name: 'SAVE_CONTAINER_ON_FAIL'),
        booleanParam(defaultValue: false, description: '', name: 'SAVE_CONTAINER_ON_PASS'),
        booleanParam(defaultValue: true, description: '', name: 'SAVE_ARTIFACTS_ON_SMOKE_SUCCESS'),
        booleanParam(defaultValue: true, description: '', name: 'DO_STAGE_4'),
        booleanParam(defaultValue: true, description: '',  name: 'DO_BUILD'),
        booleanParam(defaultValue: true, description: '', name: 'DO_INSTALL'),
        booleanParam(defaultValue: true, description: '', name: 'DO_SMOKE'),
        booleanParam(defaultValue: true, description: '', name: 'DO_DOCKERPUSH'),
        booleanParam(defaultValue: false, description: '', name: 'SAVE_ARTIFACTS_OVERRIDE'),
        string(defaultValue: '/home/jenkins/hive/openstack-etsi.rc', description: '', name: 'HIVE_VIM_1'),
    ])
])

def uninstall_osm(stackName) {
    sh """
         export OSM_USE_LOCAL_DEVOPS=true
         export PATH=$PATH:/snap/bin
         installers/full_install_osm.sh -y -w /tmp/osm -t ${stackName} -s ${stackName} --test --nolxd --nodocker --nojuju --nohostports --nohostclient --uninstall
       """
}

def run_systest(stackName,tagName,testName,envfile=null) {
    tempdir = sh(returnStdout: true, script: "mktemp -d").trim()
    if ( !envfile )
    {
        sh(script: "touch ${tempdir}/env")
        envfile="${tempdir}/env"
    }
    sh "docker run --network net${stackName} --env-file ${envfile} -v ${tempdir}:/usr/share/osm-devops/systest/reports opensourcemano/osmclient:${tagName} make -C /usr/share/osm-devops/systest ${testName}"
    sh "cp ${tempdir}/* ."
    junit  '*.xml'
}

node("${params.NODE}") {

    sh 'env'

    tag_or_branch = params.GERRIT_BRANCH.replaceAll(/\./,"")

    stage("Checkout") {
        checkout scm
    }

    ci_helper = load "jenkins/ci-pipelines/ci_helper.groovy"

    def upstream_main_job = params.UPSTREAM_SUFFIX

    // upstream jobs always use merged artifacts
    upstream_main_job += '-merge'
    container_name_prefix = "osm-${tag_or_branch}"
    container_name = "${container_name_prefix}"

    keep_artifacts = false
    if ( JOB_NAME.contains('merge') ) {
        container_name += "-merge"

        // On a merge job, we keep artifacts on smoke success
        keep_artifacts = params.SAVE_ARTIFACTS_ON_SMOKE_SUCCESS
    }
    container_name += "-${BUILD_NUMBER}"

    // Copy the artifacts from the upstream jobs
    stage("Copy Artifacts") {
        // cleanup any previous repo
        sh 'rm -rf repo'
        dir("repo") {
            // grab all stable upstream builds based on the

            dir("${RELEASE}") {
                def list = ["RO", "openvim", "osmclient", "IM", "devops", "MON", "N2VC", "NBI", "common", "LCM", "POL", "LW-UI"]
                for (component in list) {
                    step ([$class: 'CopyArtifact',
                           projectName: "${component}${upstream_main_job}/${GERRIT_BRANCH}"])

                    // grab the build name/number
                    //options = get_env_from_build('build.env')
                    build_num = ci_helper.get_env_value('build.env','BUILD_NUMBER')

                    // grab the archives from the stage_2 builds (ie. this will be the artifacts stored based on a merge)
                    ci_helper.get_archive(params.ARTIFACTORY_SERVER,component,GERRIT_BRANCH, "${component}${upstream_main_job} :: ${GERRIT_BRANCH}", build_num)

                    // cleanup any prevously defined dists
                    sh "rm -rf dists"
                }

                // check if an upstream artifact based on specific build number has been requested
                // This is the case of a merge build and the upstream merge build is not yet complete (it is not deemed
                // a successful build yet). The upstream job is calling this downstream job (with the its build artifiact)
                if ( params.UPSTREAM_JOB_NAME ) {
                    step ([$class: 'CopyArtifact',
                           projectName: "${params.UPSTREAM_JOB_NAME}",
                           selector: [$class: 'SpecificBuildSelector', buildNumber: "${params.UPSTREAM_JOB_NUMBER}"]
                          ])

                    //options = get_env_from_build('build.env')
                    // grab the build name/number
                    //build_num = sh(returnStdout:true,  script: "cat build.env | awk -F= '/BUILD_NUMBER/{print \$2}'").trim()
                    build_num = ci_helper.get_env_value('build.env','BUILD_NUMBER')
                    component = ci_helper.get_mdg_from_project(ci_helper.get_env_value('build.env','GERRIT_PROJECT'))

                    // the upstream job name contains suffix with the project. Need this stripped off
                    def project_without_branch = params.UPSTREAM_JOB_NAME.split('/')[0]

                    // Remove the previous artifact for this component. Use the new upstream artifact
                    sh "rm -rf pool/${component}"

                    ci_helper.get_archive(params.ARTIFACTORY_SERVER,component,GERRIT_BRANCH, "${project_without_branch} :: ${GERRIT_BRANCH}", build_num)

                    sh "rm -rf dists"
                }
                
                // sign all the components
                for (component in list) {
                    sh "dpkg-sig --sign builder -k ${GPG_KEY_NAME} pool/${component}/*"
                }

                // now create the distro
                for (component in list) {
                    sh "mkdir -p dists/${params.REPO_DISTRO}/${component}/binary-amd64/"
                    sh "apt-ftparchive packages pool/${component} > dists/${params.REPO_DISTRO}/${component}/binary-amd64/Packages"
                    sh "gzip -9fk dists/${params.REPO_DISTRO}/${component}/binary-amd64/Packages"
                }

                // create and sign the release file
                sh "apt-ftparchive release dists/${params.REPO_DISTRO} > dists/${params.REPO_DISTRO}/Release"
                sh "gpg --yes -abs -u ${GPG_KEY_NAME} -o dists/${params.REPO_DISTRO}/Release.gpg dists/${params.REPO_DISTRO}/Release"

                // copy the public key into the release folder
                // this pulls the key from the home dir of the current user (jenkins)
                sh "cp ~/${REPO_KEY_NAME} ."

                // merge the change logs
                sh """
                   rm -f changelog/changelog-osm.html
                   [ ! -d changelog ] || for mdgchange in \$(ls changelog); do cat changelog/\$mdgchange >> changelog/changelog-osm.html; done
                   """
                RELEASE_DIR = sh(returnStdout:true,  script: 'pwd').trim()
            }
            // start an apache server to serve up the images
            http_server_name = "${container_name}-apache"

            pwd = sh(returnStdout:true,  script: 'pwd').trim()
            repo_base_url = ci_helper.start_http_server(pwd,http_server_name)
        }

        // now pull the devops package and install in temporary location
        tempdir = sh(returnStdout: true, script: "mktemp -d").trim()
        osm_devops_dpkg = sh(returnStdout: true, script: "find . -name osm-devops*.deb").trim()
        sh "dpkg -x ${osm_devops_dpkg} ${tempdir}"
        OSM_DEVOPS="${tempdir}/usr/share/osm-devops"
    }

    dir(OSM_DEVOPS) {
        error = null
        if ( params.DO_BUILD ) {
            stage("Build") {
                sh "make -C docker clean"
                sh "make -C docker Q= CMD_DOCKER_ARGS= TAG=${container_name} RELEASE=${params.RELEASE} REPOSITORY_BASE=${repo_base_url} REPOSITORY_KEY=${params.REPO_KEY_NAME} REPOSITORY=${params.REPO_DISTRO}"
            }
        }

        try {
            if ( params.DO_INSTALL ) {
                stage("Install") {

                    //will by default always delete containers on complete
                    //sh "jenkins/system/delete_old_containers.sh ${container_name_prefix}"

                    commit_id = ''
                    repo_distro = ''
                    repo_key_name = ''
                    release = ''

                    if ( params.COMMIT_ID )
                    {
                        commit_id = "-b ${params.COMMIT_ID}"
                    }

                    if ( params.REPO_DISTRO )
                    {
                        repo_distro = "-r ${params.REPO_DISTRO}"
                    }

                    if ( params.REPO_KEY_NAME )
                    {
                        repo_key_name = "-k ${params.REPO_KEY_NAME}"
                    }

                    if ( params.RELEASE )
                    {
                        release = "-R ${params.RELEASE}"
                    }
             
                    if ( params.REPOSITORY_BASE )
                    {
                        repo_base_url = "-u ${params.REPOSITORY_BASE}"
                    }
					if ( params.DO_STAGE_4 ) {
					    try {
                        sh "docker stack list |grep \"${container_name_prefix}\"|  awk '{ print \$1 }'| xargs docker stack rm"
						}
						catch (caughtError) {
						  println("Caught error: docker stack rm failed!")
						}
					}
                    sh """
                        export PATH=$PATH:/snap/bin
                        installers/full_install_osm.sh -y -s ${container_name} --test --nolxd --nodocker --nojuju --nohostports --nohostclient \
                                                        --nodockerbuild -t ${container_name} \
                                                        -w /tmp/osm \
                                                        ${commit_id} \
                                                        ${repo_distro} \
                                                        ${repo_base_url} \
                                                        ${repo_key_name} \
                                                        ${release} \
                                                        ${params.BUILD_FROM_SOURCE}
                       """
                }
            }

            stage_archive = false
            if ( params.DO_SMOKE ) {
                stage("OSM Health") {
                    sh "installers/osm_health.sh -s ${container_name}"
                }
                stage("Smoke") {
                    run_systest(container_name,container_name,"smoke")
                    // archive smoke success until stage_4 is ready

                    if ( ! currentBuild.result.equals('UNSTABLE') ) {
                        stage_archive = keep_artifacts
                    } else {
					   error = new Exception("Smoke test failed")
					   currentBuild.result = 'FAILURE'
					}
                }
            }

            if ( params.DO_STAGE_4 ) {
                // override stage_archive to only archive on stable
                stage_archive = false
                stage("stage_4") {
                    run_systest(container_name,container_name,"openstack_stage_4",params.HIVE_VIM_1)

                    if ( ! currentBuild.result.equals('UNSTABLE') ) {
                        stage_archive = keep_artifacts
                    } else {
					   error = new Exception("Systest test failed")
					   currentBuild.result = 'FAILURE'
					}
                }
            }

            // override to save the artifacts
            if ( params.SAVE_ARTIFACTS_OVERRIDE || stage_archive ) {
                stage("Archive") {
                    sh "echo ${container_name} > build_version.txt"
                    archiveArtifacts artifacts: "build_version.txt", fingerprint: true

                    // Archive the tested repo
                    dir("${RELEASE_DIR}") {
                        ci_helper.archive(params.ARTIFACTORY_SERVER,RELEASE,GERRIT_BRANCH,'tested')
                    }
                    if ( params.DO_DOCKERPUSH ) {
                        stage("Docker Push") {
                            sh "make -C docker push INPUT_TAG=${container_name} TAG=${params.DOCKER_TAG}"
                        }
                    }
                }
            }
        }
        catch(caughtError) {
            println("Caught error!")
            error = caughtError
            currentBuild.result = 'FAILURE'
        }
        finally {


            if ( params.DO_INSTALL ) {
                if (error) {
                    if ( !params.SAVE_CONTAINER_ON_FAIL ) {
                        uninstall_osm container_name
                        sh "docker stop ${http_server_name}"
                        sh "docker rm ${http_server_name}"
                    }
                    throw error 
                }
                else {
                    if ( !params.SAVE_CONTAINER_ON_PASS ) {
                        uninstall_osm container_name
                        sh "docker stop ${http_server_name}"
                        sh "docker rm ${http_server_name}"
                    }
                }
            }
        }
    }
}
