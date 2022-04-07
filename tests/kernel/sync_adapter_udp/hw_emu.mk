# Copyright 2019-2021 Xilinx, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# vitis makefile-generator v2.0.4

############################## Help Section ##############################
.PHONY: help

help::
	$(ECHO) "Makefile Usage:"
	$(ECHO) "  make all TARGET=<hw/hw_emu/sw_emu/> PLATFORM=<FPGA platform> HOST_ARCH=<x86>"
	$(ECHO) "      Command to generate the design for specified Target and Shell."
	$(ECHO) "      By default, HOST_ARCH=x86. HOST_ARCH is required for SoC shells"
	$(ECHO) ""
	$(ECHO) "  make run TARGET=<hw/hw_emu/sw_emu/> PLATFORM=<FPGA platform> HOST_ARCH=<x86>"
	$(ECHO) "      Command to run application in emulation."
	$(ECHO) "      By default, HOST_ARCH=x86. HOST_ARCH required for SoC shells"
	$(ECHO) ""
	$(ECHO) "  make xclbin TARGET=<hw/hw_emu/sw_emu/> PLATFORM=<FPGA platform> HOST_ARCH=<x86>"
	$(ECHO) "      Command to build xclbin application."
	$(ECHO) "      By default, HOST_ARCH=x86. HOST_ARCH is required for SoC shells"
	$(ECHO) ""
	$(ECHO) "  make host HOST_ARCH=<hw/hw_emu/sw_emu/>"
	$(ECHO) "      Command to build host application."
	$(ECHO) "      By default, HOST_ARCH=x86. HOST_ARCH is required for SoC shells"
	$(ECHO) ""
	$(ECHO) "  NOTE: For embedded devices, e.g. zcu102/zcu104/vck190, env variable SYSROOT and EDGE_COMMON_SW need to be set first, and HOST_ARCH is either aarch32 or aarch64. For example,"
	$(ECHO) "       export SYSROOT=< path-to-platform-sysroot >"
	$(ECHO) "       export EDGE_COMMON_SW=< path-to-rootfs-and-Image-files >"
	$(ECHO) ""
	$(ECHO) "  make clean "
	$(ECHO) "      Command to remove the generated non-hardware files."
	$(ECHO) ""
	$(ECHO) "  make cleanall"
	$(ECHO) "      Command to remove all the generated files."
	$(ECHO) ""

############################## Setting up Project Variables ##############################

MK_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
XF_PROJ_ROOT ?= $(shell bash -c 'export MK_PATH=$(MK_PATH); echo $${MK_PATH%/tests/*}')
CUR_DIR := $(patsubst %/,%,$(dir $(MK_PATH)))
XFLIB_DIR = $(XF_PROJ_ROOT)

# setting devault value
TARGET ?= hw
HOST_ARCH ?= x86

#setting PLATFORM
ifeq ($(PLATFORM),)
PLATFORM := $(DEVICE)
endif
ifeq ($(PLATFORM),)
PLATFORM := xilinx_u55c_gen3x16_xdma_2_202110_1
endif

# #################### Checking if PLATFORM in whitelist ############################
PLATFORM_ALLOWLIST +=  u55
PLATFORM_BLOCKLIST +=  zc

include ./utils.mk

ifeq ($(TARGET),hw)
include $(XFLIB_DIR)/network/udp/hw/config.mk
endif

TEMP_DIR := _x_temp.$(TARGET).$(PLATFORM_NAME)
TEMP_REPORT_DIR := $(CUR_DIR)/reports/_x.$(TARGET).$(PLATFORM_NAME)
BUILD_DIR := build_dir.$(TARGET).$(PLATFORM_NAME)/$(HOST)
BUILD_REPORT_DIR := $(CUR_DIR)/reports/_build.$(TARGET).$(PLATFORM_NAME)
EMCONFIG := $(BUILD_DIR)/emconfig.json
XCLBIN_DIR := $(CUR_DIR)/$(BUILD_DIR)
export XCL_BINDIR = $(XCLBIN_DIR)

EXE_FILE_DEPS :=
BINARY_CONTAINERS_DEPS :=
RUN_DEPS :=

# get global setting
ifeq ($(HOST_ARCH), x86)

CXXFLAGS += -fmessage-length=0 -I$(CUR_DIR)/src/ -I$(XILINX_XRT)/include -I$(XILINX_HLS)/include -std=c++14 -Wall -Wno-unknown-pragmas -Wno-unused-label 
LDFLAGS += -pthread -L$(XILINX_XRT)/lib -L$(XILINX_HLS)/lnx64/tools/fpo_v7_0  -Wl,--as-needed -lxrt_core -lrt -lstdc++ -luuid -lxrt_coreutil 
VPP_FLAGS += -t $(TARGET) --platform $(XPLATFORM) --save-temps 
#VPP_LDFLAGS += --optimize 2 -R 2
VPP_LDFLAGS += --debug 
else ifeq ($(HOST_ARCH), aarch64)
CXXFLAGS +=  -fmessage-length=0 --sysroot=$(SYSROOT)  -I$(SYSROOT)/usr/include/xrt -I$(XILINX_HLS)/include -std=c++14 -Wall -Wno-unknown-pragmas -Wno-unused-label 
LDFLAGS += -pthread -L$(SYSROOT)/usr/lib -L$(XILINX_VITIS_AIETOOLS)/lib/aarch64.o -Wl,--as-needed -lxilinxopencl -lxrt_coreutil 
VPP_FLAGS += -t $(TARGET) --platform $(XPLATFORM) --save-temps
 
#VPP_LDFLAGS += --optimize 2 -R 2 
VPP_LDFLAGS += --debug
endif
CXXFLAGS += $(EXTRA_CXXFLAGS)
VPP_FLAGS += $(EXTRA_VPP_FLAGS)

########################## Setting up Host Variables ##########################

ifeq ($(TARGET),sw_emu)
CXXFLAGS += -D SW_EMU_TEST
endif
ifeq ($(TARGET),hw_emu)
CXXFLAGS += -D HW_EMU_TEST
endif

#Inclue Required Host Source Files
HOST_SRCS += $(XFLIB_DIR)/tests/kernel/sync_adapter_udp/host/main.cpp $(XFLIB_DIR)/common/sw/src/xNativeFPGA.cpp
SERVER_SRCS += $(XFLIB_DIR)/tests/kernel/sync_adapter_udp/host/server.cpp
CXXFLAGS +=  -D AL_mtuBytes=1472 -D AL_maxConnections=16 -D AL_netDataBits=512 -D AL_userBits=0 -D AL_destBits=16 
CXXFLAGS +=  -I $(XFLIB_DIR)/tests/kernel/sync_adapter_udp/host -I $(XFLIB_DIR)/kernel/hw/include -I $(XFLIB_DIR)/kernel/sw/include -I $(XFLIB_DIR)/common/sw/include
#CXXFLAGS += -O3 
CXXFLAGS += -g -O0 
CXXFLAGS += -Wno-unused-variable -Wno-format -Wno-sign-compare

EXE_NAME := host.exe
SERVER_EXE_NAME := server.exe
EXE_FILE := $(BUILD_DIR)/$(EXE_NAME)
SERVER_EXE_FILE := $(BUILD_DIR)/$(SERVER_EXE_NAME)
EXE_FILE_DEPS := $(HOST_SRCS) $(EXE_FILE_DEPS)
SERVER_EXE_FILE_DEPS := $(SERVER_SRCS) $(SERVER_EXE_FILE_DEPS)

########################## Kernel compiler global settings ##########################
VPP_FLAGS +=  -D AL_mtuBytes=1472 -D AL_maxConnections=16 -D AL_netDataBits=512 -D AL_userBits=0 -D AL_destBits=16
VPP_FLAGS +=  -I $(XFLIB_DIR)/common/hw/include -I $(XFLIB_DIR)/kernel/hw/include -I $(XFLIB_DIR)/adapter/hw/include -I $(XFLIB_DIR)/tests/kernel/sync_adapter_udp/kernel
VPP_LDFLAGS += --config $(CUR_DIR)/conn_u55_hw_emu.cfg



######################### binary container global settings ##########################
VPP_FLAGS_krnl_testApp +=  -D KERNEL_NAME=krnl_testApp
VPP_FLAGS_krnl_testApp += --hls.clock 300000000:krnl_testApp
VPP_FLAGS_krnl_xnikSyncTX += --hls.clock 300000000:krnl_xnikSyncTX
VPP_FLAGS_krnl_xnikSyncRX += --hls.clock 300000000:krnl_xnikSyncRX
VPP_FLAGS_krnl_xnik_tx += --hls.clock 300000000:krnl_xnik_tx
VPP_FLAGS_krnl_xnik_rx += --hls.clock 300000000:krnl_xnik_rx
VPP_FLAGS_krnl_dummyManager += --hls.clock 300000000:krnl_dummyManager
ifneq ($(HOST_ARCH), x86)
VPP_LDFLAGS_krnl_testApp += --clock.defaultFreqHz 200000000
else
VPP_LDFLAGS_krnl_testApp += --kernel_frequency 200
endif

ifeq ($(HOST_ARCH), x86)
BINARY_CONTAINERS += $(BUILD_DIR)/krnl_xnikSyncAdapter.xclbin
else
BINARY_CONTAINERS += $(BUILD_DIR)/krnl_xnikSyncAdapter_pkg.xclbin
BINARY_CONTAINERS_PKG += $(BUILD_DIR)/krnl_xnikSyncAdapter.xclbin
endif

# ################ Setting Rules for Binary Containers (Building Kernels) ################
$(TEMP_DIR)/krnl_testApp.xo: $(XFLIB_DIR)/tests/kernel/sync_adapter_udp/kernel/krnl_testApp.cpp 
	$(ECHO) "Compiling Kernel: krnl_testApp"
	mkdir -p $(TEMP_DIR)
	$(VPP) -c $(VPP_FLAGS_krnl_testApp) $(VPP_FLAGS) -k krnl_testApp -I'$(<D)' --temp_dir $(TEMP_DIR) --report_dir $(TEMP_REPORT_DIR) -o'$@' '$<'
$(TEMP_DIR)/krnl_xnikSyncTX.xo: $(XFLIB_DIR)/kernel/hw/src/krnl_xnikSyncTX.cpp 
	$(ECHO) "Compiling Kernel: krnl_xnikSyncTX"
	mkdir -p $(TEMP_DIR)
	$(VPP) -c $(VPP_FLAGS_krnl_xnikSyncTX) $(VPP_FLAGS) -k krnl_xnikSyncTX -I'$(<D)' --temp_dir $(TEMP_DIR) --report_dir $(TEMP_REPORT_DIR) -o'$@' '$<'
$(TEMP_DIR)/krnl_xnikSyncRX.xo: $(XFLIB_DIR)/kernel/hw/src/krnl_xnikSyncRX.cpp 
	$(ECHO) "Compiling Kernel: krnl_xnikSyncRX"
	mkdir -p $(TEMP_DIR)
	$(VPP) -c $(VPP_FLAGS_krnl_xnikSyncRX) $(VPP_FLAGS) -k krnl_xnikSyncRX -I'$(<D)' --temp_dir $(TEMP_DIR) --report_dir $(TEMP_REPORT_DIR) -o'$@' '$<'
$(TEMP_DIR)/krnl_xnik_tx.xo: $(XFLIB_DIR)/adapter/hw/src/krnl_xnik_tx.cpp 
	$(ECHO) "Compiling Kernel: krnl_xnik_tx"
	mkdir -p $(TEMP_DIR)
	$(VPP) -c $(VPP_FLAGS_krnl_xnik_tx) $(VPP_FLAGS) -k krnl_xnik_tx -I'$(<D)' --temp_dir $(TEMP_DIR) --report_dir $(TEMP_REPORT_DIR) -o'$@' '$<'
$(TEMP_DIR)/krnl_xnik_rx.xo: $(XFLIB_DIR)/adapter/hw/src/krnl_xnik_rx.cpp 
	$(ECHO) "Compiling Kernel: krnl_xnik_rx"
	mkdir -p $(TEMP_DIR)
	$(VPP) -c $(VPP_FLAGS_krnl_xnik_rx) $(VPP_FLAGS) -k krnl_xnik_rx -I'$(<D)' --temp_dir $(TEMP_DIR) --report_dir $(TEMP_REPORT_DIR) -o'$@' '$<'
$(TEMP_DIR)/krnl_dummyManager.xo: $(XFLIB_DIR)/tests/kernel/sync_adapter_udp/kernel/krnl_dummyManager.cpp 
	$(ECHO) "Compiling Kernel: krnl_dummyManager"
	mkdir -p $(TEMP_DIR)
	$(VPP) -c $(VPP_FLAGS_krnl_dummyManager) $(VPP_FLAGS) -k krnl_dummyManager -I'$(<D)' --temp_dir $(TEMP_DIR) --report_dir $(TEMP_REPORT_DIR) -o'$@' '$<'


BINARY_CONTAINER_krnl_testApp_OBJS += $(TEMP_DIR)/krnl_testApp.xo
BINARY_CONTAINERS_DEPS += $(BINARY_CONTAINER_krnl_testApp_OBJS)
BINARY_CONTAINER_xnik_OBJS += $(TEMP_DIR)/krnl_xnikSyncTX.xo
BINARY_CONTAINERS_DEPS += $(BINARY_CONTAINER_xnik_OBJS)
BINARY_CONTAINER_xnik_OBJS += $(TEMP_DIR)/krnl_xnikSyncRX.xo
BINARY_CONTAINERS_DEPS += $(BINARY_CONTAINER_xnik_OBJS)
BINARY_CONTAINER_xnik_OBJS += $(TEMP_DIR)/krnl_xnik_tx.xo
BINARY_CONTAINERS_DEPS += $(BINARY_CONTAINER_xnik_OBJS)
BINARY_CONTAINER_xnik_OBJS += $(TEMP_DIR)/krnl_xnik_rx.xo
BINARY_CONTAINERS_DEPS += $(BINARY_CONTAINER_xnik_OBJS)
BINARY_CONTAINER_xnik_OBJS += $(TEMP_DIR)/krnl_dummyManager.xo
BINARY_CONTAINERS_DEPS += $(BINARY_CONTAINER_xnik_OBJS)
BINARY_CONTAINERS_DEPS += $(LIST_XO)

$(BINARY_CONTAINERS): $(BINARY_CONTAINERS_DEPS)
	mkdir -p $(BUILD_DIR)
	$(VPP) -l $(VPP_FLAGS) --temp_dir $(TEMP_DIR) --report_dir $(BUILD_REPORT_DIR)/krnl_testApp $(VPP_LDFLAGS)  $(VPP_LDFLAGS_krnl_testApp) $(AIE_LDFLAGS)   -o $@ $^

############################## Setting Rules for Host (Building Host Executable) ##############################
ifeq ($(HOST_ARCH), x86)
$(EXE_FILE): $(EXE_FILE_DEPS) |  check_xrt
	mkdir -p $(BUILD_DIR)
	$(CXX) -o $@ $^ $(CXXFLAGS) $(LDFLAGS)

$(SERVER_EXE_FILE): $(SERVER_EXE_FILE_DEPS)
	mkdir -p $(BUILD_DIR)
	$(CXX) -o $@ $^ $(CXXFLAGS) $(LDFLAGS)
else
$(EXE_FILE): $(EXE_FILE_DEPS) |  check_sysroot
	mkdir -p $(BUILD_DIR)
	$(CXX) -o $@ $^ $(CXXFLAGS) $(LDFLAGS)

endif

$(EMCONFIG):
	emconfigutil --platform $(XPLATFORM) --od $(BUILD_DIR)
############################## Preparing sdcard folder ##############################
ifneq ($(HOST_ARCH), x86)
ifneq (,$(findstring zc706, $(PLATFORM_NAME)))
K_IMAGE := $(SYSROOT)/../../uImage
else
K_IMAGE := $(SYSROOT)/../../Image
endif
RUN_SCRIPT := $(BUILD_DIR)/run_script.sh
$(RUN_SCRIPT):
	rm -rf $(RUN_SCRIPT)
	@echo 'export LD_LIBRARY_PATH=/mnt:/tmp:$(LIBRARY_PATH)' >> $(RUN_SCRIPT)
ifneq ($(filter sw_emu hw_emu, $(TARGET)),)
	@echo 'export XCL_EMULATION_MODE=$(TARGET)' >> $(RUN_SCRIPT)
endif
	@echo 'export XILINX_VITIS=/mnt' >> $(RUN_SCRIPT)
	@echo 'export XILINX_XRT=/usr' >> $(RUN_SCRIPT)
	@echo 'if [ -f platform_desc.txt  ]; then' >> $(RUN_SCRIPT)
	@echo '        cp platform_desc.txt /etc/xocl.txt' >> $(RUN_SCRIPT)
	@echo 'fi' >> $(RUN_SCRIPT)
	@echo './$(EXE_NAME) $(PKG_HOST_ARGS)' >> $(RUN_SCRIPT)
	@echo 'return_code=$$?' >> $(RUN_SCRIPT)
	@echo 'if [ $$return_code -ne 0 ]; then' >> $(RUN_SCRIPT)
	@echo '        echo "ERROR: Embedded host run failed, RC=$$return_code"' >> $(RUN_SCRIPT)
	@echo 'else' >> $(RUN_SCRIPT)
	@echo '        echo "INFO: TEST PASSED, RC=0"' >> $(RUN_SCRIPT)
	@echo 'fi' >> $(RUN_SCRIPT)
	@echo 'echo "INFO: Embedded host run completed."' >> $(RUN_SCRIPT)
	@echo 'exit $$return_code' >> $(RUN_SCRIPT)
DATA_FILE := 
DATA_DIR := 
SD_FILES += $(RUN_SCRIPT)
SD_FILES += $(EXE_FILE)
SD_FILES += $(EMCONFIG)
SD_FILES += xrt.ini
SD_FILES += $(DATA_FILE)# where define DATAFILE in json
SD_FILES_WITH_PREFIX = $(foreach sd_file,$(SD_FILES), $(if $(filter $(sd_file),$(wildcard $(sd_file))), --package.sd_file $(sd_file)))
SD_DIRS_WITH_PREFIX = $(foreach sd_dir,$(DATA_DIR),--package.sd_dir $(sd_dir))
PACKAGE_FILES := $(BINARY_CONTAINERS)
PACKAGE_FILES += $(AIE_CONTAINER)
SD_CARD := $(CUR_DIR)/package_$(TARGET)
$(SD_CARD): $(EXE_FILE) $(BINARY_CONTAINERS) $(RUN_SCRIPT) $(EMCONFIG)
	@echo "Generating sd_card folder...."
	mkdir -p $(SD_CARD)
	chmod a+rx $(BUILD_DIR)/run_script.sh
	$(VPP) -t $(TARGET) --platform $(XPLATFORM) -o $(BINARY_CONTAINERS_PKG) -p $(PACKAGE_FILES) $(VPP_PACKAGE) --package.out_dir  $(SD_CARD) --package.rootfs $(SYSROOT)/../../rootfs.ext4 --package.kernel_image $(K_IMAGE)  $(SD_FILES_WITH_PREFIX) $(SD_DIRS_WITH_PREFIX)
	@echo "### ***** sd_card generation done! ***** ###"

.PHONY: sd_card
sd_card: $(SD_CARD)
endif
############################## Setting Essential Checks and Building Rules ##############################

.PHONY: all clean cleanall emconfig
emconfig: $(EMCONFIG)
ifeq ($(HOST_ARCH), x86)
all:  check_vpp check_platform check_xrt $(EXE_FILE) $(BINARY_CONTAINERS) emconfig
else
all:  check_vpp check_platform check_sysroot $(EXE_FILE) $(BINARY_CONTAINERS) emconfig sd_card
endif

.PHONY: host server
ifeq ($(HOST_ARCH), x86)
host:  check_xrt $(EXE_FILE)
server: $(SERVER_EXE_FILE)
else
host:  check_sysroot $(EXE_FILE)
endif

.PHONY: xclbin
ifeq ($(HOST_ARCH), x86)
ifeq ($(TARGET),hw)
xclbin:  check_vpp check_xrt create-conf-file buildip $(BINARY_CONTAINERS)
else
xclbin:  check_vpp check_xrt $(BINARY_CONTAINERS) 
endif
else
xclbin:  check_vpp check_sysroot $(BINARY_CONTAINERS) 
endif

############################## Cleaning Rules ##############################
cleanh:
	-$(RMDIR) $(EXE_FILE) $(SERVER_EXE_FILE)  vitis_* TempConfig system_estimate.xtxt *.rpt .run/
	-$(RMDIR) src/*.ll _xocc_* .Xil dltmp* xmltmp* *.log *.jou *.wcfg *.wdb sample_link.ini sample_compile.ini obj*  bin* *.csv *.jpg *.jpeg *.png

cleank:
	-$(RMDIR) $(BUILD_DIR)/*.xclbin _vimage *xclbin.run_summary qemu-memory-_* emulation/ _vimage/ pl*start_simulation. sh *.xclbin
	-$(RMDIR) _x_temp.*/_x.* _x_temp.*/.Xil _x_temp.*/profile_summary.* xo_* _x*
	-$(RMDIR) _x_temp.*/dltmp* _x_temp.*/kernel_info.dat _x_temp.*/*.log
	-$(RMDIR) _x_temp.* 

cleanall: cleanh cleank
	-$(RMDIR) $(BUILD_DIR)  build_dir.* emconfig.json *.html $(TEMP_DIR) $(CUR_DIR)/reports *.csv *.run_summary  $(CUR_DIR)/*.raw package_*   $(BUILD_DIR)/run_script.sh .ipcache *.str
	-$(RMDIR) $(XFLIB_DIR)/common/data/*.xe2xd* $(XFLIB_DIR)/common/data/*.orig*
	-$(RMDIR)  $(CUR_DIR)/Work $(CUR_DIR)/*.xpe $(CUR_DIR)/hw.o $(CUR_DIR)/*.xsa $(CUR_DIR)/xnwOut

clean: cleanh
