#
#   Copyright 2017 Sandvine
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

TOPDIR=$(shell readlink -f .|sed -e 's/\/descriptor-packages\/.*//')
TOOLS_DIR := $(TOPDIR)/tools

SUBDIRS_CLEAN = $(addsuffix .clean, $(SUBDIRS))
SUBDIRS_TEST = $(addsuffix .test, $(SUBDIRS))
SUBDIRS_TAG = $(addsuffix .tag, $(SUBDIRS))
SUBDIRS_PUSH = $(addsuffix .push, $(SUBDIRS))

.PHONY: $(SUBDIRS) $(SUBDIRS_CLEAN) clean test tag push

all: $(SUBDIRS)

clean: $(SUBDIRS_CLEAN)

test: $(SUBDIRS_TEST)

tag: $(SUBDIRS_TAG)

push: $(SUBDIRS_PUSH)

$(SUBDIRS_CLEAN): %.clean:
	@$(MAKE) --no-print-directory -C $* clean

$(SUBDIRS_TEST): %.test:
	@$(MAKE) --no-print-directory -C $* test

$(SUBDIRS_TAG): %.tag:
	@$(MAKE) --no-print-directory -C $* tag 

$(SUBDIRS_PUSH): %.push:
	@$(MAKE) --no-print-directory -C $* push

$(SUBDIRS):
	@$(MAKE) --no-print-directory -C $@

test:
	$(TOOLS_DIR)/launch_tests.sh
