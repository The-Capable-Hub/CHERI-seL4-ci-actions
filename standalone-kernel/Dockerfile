# Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
#
# SPDX-License-Identifier: BSD-2-Clause
ARG BASE_IMG
FROM $BASE_IMG

COPY compile_kernel.sh /compile_kernel.sh

ENTRYPOINT ["/compile_kernel.sh"]
