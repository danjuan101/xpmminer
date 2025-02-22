cmake_minimum_required(VERSION 2.8)

option(DEBUG_MINING_AMD_OPENCL "Print performance counters")
option(BUILDCPUMINER "build CPU miner" ON)
option(BUILDOPENCLMINER "build OpenCL miner" ON)
option(BUILDCUDAMINER "build CUDA miner" ON)

set (CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH}
  ${CMAKE_SOURCE_DIR}/cmake
)

find_package(OpenSSL REQUIRED)
IF (BUILDOPENCLMINER)
  include(FindOpenCL)
endif()
include(FindDependencies)
include(TestBigEndian)
include(CheckTypeSize)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++0x")

if (WIN32)
  add_definitions(-DWIN32 -DCURL_STATICLIB -DPTW32_STATIC_LIB -D__USE_MINGW_ANSI_STDIO=0)
  set(OS_WINDOWS 1)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(OS_LINUX 1)
  set(OS_COMMONUNIX 1)
elseif (APPLE)
  set(OS_DARWIN 1)
  set(OS_COMMONUNIX 1)
elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
  set(OS_FREEBSD 1) 
  set(OS_COMMONUNIX 1)
endif()

if(MSVC)
  add_definitions(
    -D_CRT_SECURE_NO_DEPRECATE
    -D_CRT_SECURE_NO_WARNINGS
    -D_CRT_NONSTDC_NO_DEPRECATE
  )
endif(MSVC)

TEST_BIG_ENDIAN(IS_BIGENDIAN)
CHECK_TYPE_SIZE(__int128 INT128_SIZE)
if (NOT INT128_SIZE)
  set(INT128_SIZE 0)
endif()

configure_file(
  ${CMAKE_SOURCE_DIR}/include/config.h.in
  ${CMAKE_BINARY_DIR}/include/config.h
)

include_directories(
  ${CMAKE_SOURCE_DIR}/include
  ${CMAKE_BINARY_DIR}/include
  ${CMAKE_SOURCE_DIR}/blkmaker
)

add_subdirectory(blkmaker)
add_subdirectory(common)
IF (BUILDCPUMINER)
  add_subdirectory(CPU)
ENDIF()
IF (BUILDOPENCLMINER)
  add_subdirectory(OpenCL)
ENDIF()
IF (BUILDCUDAMINER)
  add_subdirectory(Cuda)
ENDIF()