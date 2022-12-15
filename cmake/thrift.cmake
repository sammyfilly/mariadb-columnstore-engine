include(ExternalProject)

set(INSTALL_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/external/thrift)
SET(THRIFT_INCLUDE_DIRS "${INSTALL_LOCATION}/include")
SET(THRIFT_LIBRARY_DIRS "${INSTALL_LOCATION}/lib")
set(THRIFT_LIBRARY ${THRIFT_LIBRARY_DIRS}/${CMAKE_STATIC_LIBRARY_PREFIX}thrift${CMAKE_STATIC_LIBRARY_SUFFIX})


ExternalProject_Add(external_thrift
    URL https://github.com/apache/thrift/archive/refs/tags/v0.17.0.tar.gz
    URL_HASH SHA256=f5888bcd3b8de40c2c2ab86896867ad9b18510deb412cba3e5da76fb4c604c29
    PREFIX ${INSTALL_LOCATION}
    CMAKE_ARGS -DCMAKE_INSTALL_PREFIX:PATH=${INSTALL_LOCATION}
    -DBUILD_COMPILER=YES
    -DBUILD_CPP=YES
    -DBUILD_C_GLIB=YES
    -DBUILD_JAVA=NO
    -DBUILD_JAVASCRIPT=NO
    -DBUILD_KOTLIN=NO
    -DBUILD_NODEJS=NO
    -DBUILD_PYTHON=NO
    -DBUILD_TESTING=NO
    -DBUILD_SHARED_LIBS=NO
    -DCMAKE_CXX_FLAGS:STRING="-fPIC"
    -DBOOST_INCLUDEDIR=${Boost_INCLUDE_DIRS}
    -DBOOST_LIBRARYDIR=${Boost_LIBRARY_DIRS}
)

add_dependencies(external_thrift external_boost)
