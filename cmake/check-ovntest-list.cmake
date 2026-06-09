# Source-list drift guard for the CMake `ovntest` target (mirrors the OVS
# overlay's cmake/check-ovstest-list.cmake).
#
# The CMake overlay hand-maintains OVNTEST_SOURCES (it cannot read the autotools
# tests/automake.mk).  The `ovntest --help` runtime canary catches a *removed*
# module, but not upstream *adding* a new tests/test-*.c + OVSTEST_REGISTER that
# our list silently lacks -- that loses coverage with no signal.  This guard
# fails configuration if any tests/test-*.c that registers an ovstest module is
# absent from OVNTEST_SOURCES, modulo the documented platform exclusions.
#
# Only tests/test-*.c is globbed, matching the OVS guard.  The libovn-level
# modules under lib/ (test-lflow-conj-ids.c, test-ovn-features.c,
# test-ofctrl-seqno.c) are listed in OVNTEST_SOURCES directly; the controller/
# and northd/ test drivers are intentionally not built into ovntest yet (they
# need extra controller/northd objects).
#
# Requires OVNTEST_SOURCES to be set by the caller (CMakeLists.txt).

# Excluded on purpose (built into the autotools ovstest only on other platforms):
set(_ovntest_excluded
  test-ovn-netlink.c)         # tests/automake.mk: if HAVE_NETLINK (Linux only)

# Names already in our target source list.
set(_ovntest_have "")
foreach(_s ${OVNTEST_SOURCES})
  get_filename_component(_n "${_s}" NAME)
  list(APPEND _ovntest_have "${_n}")
endforeach()

file(GLOB _ovntest_all "${CMAKE_CURRENT_SOURCE_DIR}/tests/test-*.c")
set(_ovntest_missing "")
foreach(_f ${_ovntest_all})
  file(READ "${_f}" _txt)
  if(_txt MATCHES "OVSTEST_REGISTER")
    get_filename_component(_base "${_f}" NAME)
    list(FIND _ovntest_have "${_base}" _h)
    list(FIND _ovntest_excluded "${_base}" _e)
    if(_h EQUAL -1 AND _e EQUAL -1)
      list(APPEND _ovntest_missing "${_base}")
    endif()
  endif()
endforeach()

if(_ovntest_missing)
  message(FATAL_ERROR
    "ovntest source-list drift: these tests/test-*.c register OVSTEST modules but "
    "are missing from OVNTEST_SOURCES in CMakeLists.txt. Add them to the target, or "
    "(if platform-specific) to the exclusion list in cmake/check-ovntest-list.cmake: "
    "${_ovntest_missing}")
endif()
