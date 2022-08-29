/*
 * Copyright 2019-2022 Xilinx, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

#ifndef HWMANAGERHOST_HPP
#define HWMANAGERHOST_HPP

#include <cassert>
#include <vector>
#include "xNativeFPGA.hpp"

namespace AlveoLink {
namespace kernel {
template <unsigned int t_MaxConnections>
class hwManagerHost {
   public:
    hwManagerHost() {}
    void init(AlveoLink::common::FPGA* p_fpga) {
        m_card = p_fpga;
        m_krnlManager.fpga(m_card);
    }
    void createCU(const unsigned int p_id = 0) {
        std::string l_cuName = "krnl_xnikSyncManager:{krnl_xnikSyncManager_" + std::to_string(p_id) + "}";
        m_krnlManager.createKernel(l_cuName);
    }

    void runCU() {
        m_krnlManager.run();
    }

    void setConfigBuf(const uint32_t p_numDevs, const uint32_t p_waitCycles, 
                      const uint32_t p_flushCounter, const uint32_t p_startId) {
        assert(p_numDevs < t_MaxConnections);
        unsigned int l_dataBytes = sizeof(uint32_t)*16;
        uint32_t* l_configBuf = (uint32_t*)(m_krnlManager.createBO(0, l_dataBytes));
        l_configBuf[0] = p_numDevs;
        l_configBuf[1] = p_waitCycles;
        l_configBuf[2] = p_flushCounter;
        l_configBuf[3] = p_startId;
        m_krnlManager.setMemArg(0);
        m_krnlManagerBufs.insert({0, l_configBuf});
    }

    void sendBO() { m_krnlManager.sendBO(0); }
    void finish() { m_krnlManager.wait(); }

   private:
    AlveoLink::common::FPGA* m_card;
    AlveoLink::common::KERNEL m_krnlManager;
    std::map<const int, void*> m_krnlManagerBufs;
};

}
}
#endif
