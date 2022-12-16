# Low level C++ host API
This folder contains a low level API build on top of XRT to control the network
stack from C++.

The [cmake project](CMakeLists.txt) contains a library (`network_roce_v2`) that
you can link to your project, and the bindings are described in the header files
located in [`include/roce`](include/roce).
