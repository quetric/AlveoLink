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
XF_PROJ_ROOT ?= $(shell bash -c 'export MK_PATH=$(MK_PATH); echo $${MK_PATH%/L2/*}')
CUR_DIR := $(patsubst %/,%,$(dir $(MK_PATH)))
XFLIB_DIR = $(XF_PROJ_ROOT)

# setting devault value
TARGET ?= sw_emu
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
TEMP_DIR := _x_temp.$(TARGET).$(PLATFORM_NAME)
TEMP_REPORT_DIR := $(CUR_DIR)/reports/_x.$(TARGET).$(PLATFORM_NAME)
BUILD_DIR := build_dir.$(TARGET).$(PLATFORM_NAME)
BUILD_REPORT_DIR := $(CUR_DIR)/reports/_build.$(TARGET).$(PLATFORM_NAME)
EMCONFIG := $(BUILD_DIR)/emconfig.json
XCLBIN_DIR := $(CUR_DIR)/$(BUILD_DIR)
export XCL_BINDIR = $(XCLBIN_DIR)

EXE_FILE_DEPS :=
BINARY_CONTAINERS_DEPS :=
RUN_DEPS :=

# get global setting
ifeq ($(HOST_ARCH), x86)
CXXFLAGS += -fmessage-length=0 -I$(CUR_DIR)/src/ -I$(XILINX_XRT)/include -I$(XILINX_HLS)/include -I$(XF_PROJ_ROOT)/ext -std=c++14 -Wall -Wno-unknown-pragmas -Wno-unused-label 
LDFLAGS += -pthread -L$(XILINX_XRT)/lib -L$(XILINX_HLS)/lnx64/tools/fpo_v7_0  -Wl,--as-needed -lxrt_core -lrt -lstdc++ -luuid -lxrt_coreutil -lgmp -lmpfr
VPP_FLAGS += --hls.pre_tcl $(AL_PATH)/adapter/dv/hw/hls_config.tcl  -t $(TARGET) --platform $(XPLATFORM) --save-temps 
#VPP_LDFLAGS += --optimize 2 -R 2 
VPP_LDFLAGS += --debug 
else ifeq ($(HOST_ARCH), aarch64)
CXXFLAGS += -I$(CUR_DIR)/src/ -fmessage-length=0 --sysroot=$(SYSROOT)  -I$(SYSROOT)/usr/include/xrt -I$(XILINX_HLS)/include -I$(XF_PROJ_ROOT)/ext -std=c++14 -Wall -Wno-unknown-pragmas -Wno-unused-label 
LDFLAGS += -pthread -L$(SYSROOT)/usr/lib -L$(XILINX_VITIS_AIETOOLS)/lib/aarch64.o -Wl,--as-needed -lxilinxopencl -lxrt_coreutil 
VPP_FLAGS += --hls.pre_tcl $(AL_PATH)/adapter/dv/hw/hls_config.tcl -t $(TARGET) --platform $(XPLATFORM) --save-temps 
#VPP_LDFLAGS += --optimize 2 -R 2 
VPP_LDFLAGS += --debug
endif
CXXFLAGS += $(EXTRA_CXXFLAGS)
VPP_FLAGS += $(EXTRA_VPP_FLAGS)

NETSTREAM=1
########################## Setting up Host Variables ##########################
ifeq ($(NETSTREAM), 1)
CXXFLAGS += -D NETSTREAM -D NHOP_numPUs=4
endif

ifeq ($(TARGET),sw_emu)
CXXFLAGS += -D SW_EMU_TEST
endif
ifeq ($(TARGET),hw_emu)
CXXFLAGS += -D HW_EMU_TEST
endif

#Inclue Required Host Source Files
HOST_SRCS += $(XFLIB_DIR)/L2/nhop_xnik_dv/host/main_k2k.cpp $(AL_PATH)/common/sw/src/xNativeFPGA.cpp 
CXXFLAGS +=  -I $(XFLIB_DIR)/L2/nhop_xnik_dv/host -I $(AL_PATH)/common/sw/include -I $(XFLIB_DIR)/ext/xcl2 -I $(XFLIB_DIR)/../database/L1/include -I $(XFLIB_DIR)/nhop_xnik_dv -I $(XFLIB_DIR)/../database/L1/include/hw -I $(XFLIB_DIR)/../quantitative_finance/L1/include -I $(XFLIB_DIR)/../utils/L1/include
#CXXFLAGS += -O3 
CXXFLAGS += -g 
CXXFLAGS += -Wno-unused-variable -Wno-format -Wno-sign-compare

EXE_NAME := host.exe
EXE_FILE := $(BUILD_DIR)/$(EXE_NAME)
EXE_FILE_DEPS := $(HOST_SRCS) $(EXE_FILE_DEPS)

HOST_ARGS :=  --xclbin $(BUILD_DIR)/nHop_kernel.xclbin  --filepath ./as-Skitter-twoHopPair100 --hop 2 --numKernel 2 --batch 64
ifneq ($(HOST_ARCH), x86)
PKG_HOST_ARGS = $(foreach args,$(HOST_ARGS),$(subst $(dir $(patsubst %/,%,$(args))),,$(args)))
endif

########################## Kernel compiler global settings ##########################
ifneq (,$(shell echo $(XPLATFORM) | awk '/u55/'))
ifeq ($(NETSTREAM), 1)
VPP_FLAGS += -D NETSTREAM
VPP_LDFLAGS +=   --config $(CUR_DIR)/conn_u55_k2k.cfg 
else
VPP_LDFLAGS +=   --config $(CUR_DIR)/conn_u55.cfg
endif

VPP_FLAGS +=  -I $(XFLIB_DIR)/L2/nhop_xnik_dv -I $(XFLIB_DIR)/L2/nhop_xnik_dv/kernel -I $(XFLIB_DIR)/../database/L1/include/hw -I $(XFLIB_DIR)/../quantitative_finance/L1/include -I $(XFLIB_DIR)/../utils/L1/include

else 
VPP_FLAGS +=  -I $(XFLIB_DIR)/L2/nhop_xnik_dv -I $(XFLIB_DIR)/L2/nhop_xnik_dv/kernel -I $(XFLIB_DIR)/../database/L1/include/hw -I $(XFLIB_DIR)/../quantitative_finance/L1/include -I $(XFLIB_DIR)/../utils/L1/include

endif

######################### binary container global settings ##########################
VPP_FLAGS_nHop_kernel +=  -D KERNEL_NAME=nHop_kernel
VPP_FLAGS_nHop_kernel += --hls.clock 300000000:nHop_kernel
switch_kernel_VPP_FLAGS +=  -D KERNEL_NAME=switch_kernel
switch_kernel_VPP_FLAGS += --hls.clock 300000000:switch_kernel
ifneq ($(HOST_ARCH), x86)
VPP_LDFLAGS_nHop_kernel += --clock.defaultFreqHz 150000000
else
VPP_LDFLAGS_nHop_kernel += --kernel_frequency 150
endif

VPP_LDFLAGS_nHop_temp :=  --connectivity.nk nHop_kernel:2:nHop_kernel0.nHop_kernel1 --connectivity.nk switch_kernel:1:switch_kernel
VPP_LDFLAGS_nHop_kernel += $(VPP_LDFLAGS_nHop_temp)
nHop_kernel_ARGS += $(XFLIB_DIR)/L2/nhop_xnik_dv/kernel/hls_memfifo.cpp

ifeq ($(HOST_ARCH), x86)
BINARY_CONTAINERS += $(BUILD_DIR)/nHop_kernel.xclbin
else
BINARY_CONTAINERS += $(BUILD_DIR)/nHop_kernel_pkg.xclbin
BINARY_CONTAINERS_PKG += $(BUILD_DIR)/nHop_kernel.xclbin
endif

# ################ Setting Rules for Binary Containers (Building Kernels) ################
$(TEMP_DIR)/nHop_kernel.xo: $(XFLIB_DIR)/L2/nhop_xnik_dv/kernel/nHop_kernel.cpp $(nHop_kernel_ARGS)
	$(ECHO) "Compiling Kernel: nHop_kernel"
	mkdir -p $(TEMP_DIR)
	$(VPP) -c $(VPP_FLAGS_nHop_kernel) $(VPP_FLAGS) -k nHop_kernel -I'$(<D)' --temp_dir $(TEMP_DIR) --report_dir $(TEMP_REPORT_DIR) -o'$@' $^ 
$(TEMP_DIR)/switch_kernel.xo: $(XFLIB_DIR)/L2/nhop_xnik_dv/kernel/switch_kernel.cpp 
	$(ECHO) "Compiling Kernel: switch_kernel"
	mkdir -p $(TEMP_DIR)
	$(VPP) -c $(switch_kernel_VPP_FLAGS) $(VPP_FLAGS) -k switch_kernel -I'$(<D)' --temp_dir $(TEMP_DIR) --report_dir $(TEMP_REPORT_DIR) -o'$@' $^
BINARY_CONTAINER_nHop_kernel_OBJS += $(TEMP_DIR)/nHop_kernel.xo
BINARY_CONTAINER_nHop_kernel_OBJS += $(TEMP_DIR)/switch_kernel.xo
BINARY_CONTAINERS_DEPS += $(BINARY_CONTAINER_nHop_kernel_OBJS)

$(BINARY_CONTAINERS): $(BINARY_CONTAINERS_DEPS)
	mkdir -p $(BUILD_DIR)
	$(VPP) -l $(VPP_FLAGS) --temp_dir $(TEMP_DIR) --report_dir $(BUILD_REPORT_DIR)/nHop_kernel $(VPP_LDFLAGS)  $(VPP_LDFLAGS_nHop_kernel) $(AIE_LDFLAGS)   -o $@ $^

############################## Setting Rules for Host (Building Host Executable) ##############################
ifeq ($(HOST_ARCH), x86)
$(EXE_FILE): $(EXE_FILE_DEPS) |  check_xrt
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
RUN_DEPS += $(EXE_FILE) $(BINARY_CONTAINERS) $(EMCONFIG)
RUN_DEPS += $(SD_CARD)
run: check_device  $(RUN_DEPS)
#hw_emu
ifneq (,$(filter hw_emu, $(TARGET)))
ifeq ($(HOST_ARCH), x86)
	LD_LIBRARY_PATH=$(LIBRARY_PATH):$$LD_LIBRARY_PATH \
	XCL_EMULATION_MODE=$(TARGET) $(EXE_FILE) $(HOST_ARGS)
	
else
	@echo $(RUN_DEPS)
	$(SD_CARD)/launch_$(TARGET).sh -no-reboot -run-app $(notdir $(RUN_SCRIPT)) 
	grep "TEST PASSED, RC=0" $(SD_CARD)/qemu_output.log || exit 1
	
endif
endif
#sw_emu
ifneq (,$(filter sw_emu, $(TARGET)))
ifeq ($(HOST_ARCH), x86)
	LD_LIBRARY_PATH=$(LIBRARY_PATH):$$LD_LIBRARY_PATH \
	XCL_EMULATION_MODE=$(TARGET) $(EXE_FILE) $(HOST_ARGS) 
	
else
	@echo $(RUN_DEPS)
	$(SD_CARD)/launch_$(TARGET).sh -no-reboot -run-app $(notdir $(RUN_SCRIPT)) 
	grep "TEST PASSED, RC=0" $(SD_CARD)/qemu_output.log || exit 1
	
endif
endif
#hw
ifeq ($(TARGET), hw)
ifeq ($(HOST_ARCH), x86)
	$(EXE_FILE) $(HOST_ARGS)
	
else
	$(ECHO) "Please copy the content of sd_card folder and data to an SD Card and run on the board"
endif
endif

############################## Setting Targets ##############################

.PHONY: all clean cleanall emconfig
emconfig: $(EMCONFIG)
ifeq ($(HOST_ARCH), x86)
all:  check_vpp check_platform check_xrt $(EXE_FILE) $(BINARY_CONTAINERS) emconfig
else
all:  check_vpp check_platform check_sysroot $(EXE_FILE) $(BINARY_CONTAINERS) emconfig sd_card
endif

.PHONY: host
ifeq ($(HOST_ARCH), x86)
host:  check_xrt $(EXE_FILE)
else
host:  check_sysroot $(EXE_FILE)
endif

.PHONY: xclbin
ifeq ($(HOST_ARCH), x86)
xclbin:  check_vpp check_xrt $(BINARY_CONTAINERS) 
else
xclbin:  check_vpp check_sysroot $(BINARY_CONTAINERS) 
endif

############################## Cleaning Rules ##############################
cleanh:
	-$(RMDIR) $(EXE_FILE) vitis_* TempConfig system_estimate.xtxt *.rpt .run/
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
