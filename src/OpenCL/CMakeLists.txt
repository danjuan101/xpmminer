if (DEBUG_MINING_AMD_OPENCL)
  find_path(GPUPERFAPI_INCLUDE_DIRECTORY GPUPerfAPI.h)
  find_library(GPUPERFAPI_OPENCL_LIBRARY GPUPerfAPICL)
  find_library(GPUPERFAPI_OPENGL_LIBRARY GPUPerfAPIGL)

  if (OS_LINUX)
    add_definitions(-D_LINUX)
  endif()

  include_directories(${GPUPERFAPI_INCLUDE_DIRECTORY})
endif()

include_directories(
  ${GMP_INCLUDE_DIRECTORY}
  ${OPENSSL_INCLUDE_DIR}
  ${JANSSON_INCLUDE_DIRECTORY}
  ${CURL_INCLUDE_DIRECTORY}
  ${OPENCL_INCLUDE_DIRS}
)

add_executable(xpmclminer
  xpmclminer.cpp
  benchmarks.cpp
  utils.cpp
)

target_link_libraries(xpmclminer
  common
  blkmaker
  ${GMP_LIBRARY}
  ${GMPXX_LIBRARY}
  ${OPENSSL_SSL_LIBRARY}
  ${OPENSSL_CRYPTO_LIBRARY}
  ${CURL_LIBRARY}
  ${JANSSON_LIBRARY}
  ${OPENCL_LIBRARIES}
)

if (OS_LINUX)
  target_link_libraries(xpmclminer pthread dl)
elseif (OS_WINDOWS)
  set(CMAKE_EXE_LINKER_FLAGS "-static-libgcc -static-libstdc++ -static")
  target_link_libraries(xpmclminer
    ${PTHREAD_LIBRARY}
    ${Z_LIBRARY}
    ws2_32
    wldap32
  )
endif()

if (DEBUG_MINING_AMD_OPENCL)
  target_link_libraries(xpmclminer
    ${GPUPERFAPI_OPENCL_LIBRARY}
    ${GPUPERFAPI_OPENGL_LIBRARY}
  )
endif()

install(TARGETS xpmclminer DESTINATION bin)
install(FILES 
  ${CMAKE_SOURCE_DIR}/OpenCL/kernel.cl
  ${CMAKE_SOURCE_DIR}/OpenCL/sha256.h
  ${CMAKE_SOURCE_DIR}/OpenCL/fmt.h  
  DESTINATION share/xpmminer)
