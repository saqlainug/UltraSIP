# Third-party notices

MacSIP is licensed under the GNU General Public License v3 (see LICENSE).
It incorporates the following third-party software when built with the
pinned configuration in `scripts/build-pjsip.sh`. Complete corresponding
source for all GPL components is available from this repository and the
pinned upstream archives (exact versions + checksums in
DEPENDENCY_LICENSES.md).

> Binary distributions must ship this file. Update it in the same change
> as any dependency addition/upgrade (dependency-review skill).

---

## PJSIP (pjproject) 2.17

Copyright (C) 2008-2026 Teluu Inc. (http://www.teluu.com)

Licensed under the GNU General Public License, version 2 or later.
https://www.pjsip.org/licensing.htm — used here under GPLv2-or-later,
combined into this GPLv3 work.

PJSIP bundles the following third-party components that are compiled into
MacSIP's SIP core:

### libsrtp
Copyright (c) 2001-2017 Cisco Systems, Inc. All rights reserved.
BSD 3-Clause License.

### libgsm 1.0.12 (GSM 06.10)
Copyright 1992-1994 by Jutta Degener and Carsten Bormann,
Technische Universitaet Berlin.
Permissive TU-Berlin license (SPDX: TU-Berlin-2.0); notice retained per its
terms.

### iLBC (RFC 3951 reference implementation)
Copyright (C) The Internet Society (2004). All Rights Reserved.
Distributed per the RFC 3951/RFC 3978-era code-component terms as shipped
in pjproject for ~20 years. (See DEPENDENCY_LICENSES.md for the caveat on
these pre-IETF-Trust terms.)

### Speex codec and SpeexDSP
Copyright 2002-2008 Xiph.org Foundation, Jean-Marc Valin, et al.
Revised BSD License.

### WebRTC (acoustic echo cancellation modules)
Copyright (c) 2011, The WebRTC project authors. All rights reserved.
BSD 3-Clause License.

### resample (Julius O. Smith III, CCRMA)
Distributed with pjproject under its permissive terms; exact notice to be
re-verified against the pinned tree before the first binary release.

### G.722.1 / G.722.1C (Polycom Siren)
Present in the pjproject source tree but **disabled and not compiled** into
MacSIP builds (patent/licensing-encumbered; see DEPENDENCY_LICENSES.md).

---

## GNU General Public License v3 text

The LICENSE file is the verbatim GPLv3 text, © Free Software Foundation,
Inc. (https://fsf.org/); everyone is permitted to copy and distribute
verbatim copies of the license document.

---

MacSIP is an original, independent project. It is not affiliated with,
endorsed by, or derived from the assets of MicroSIP (microsip.org); the
MicroSIP name, logos, and artwork are the property of their owners and are
not used by this project.
