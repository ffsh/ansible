#!/bin/sh
dkms remove -m batman-adv -v {{ batman_version }} --all
dkms install -m batman-adv -v {{ batman_version }}
