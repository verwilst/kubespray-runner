#!/bin/bash

BASE="${PWD}"

if [ ! -f ${BASE}/kubespray.version ]; then
	echo "No kubespray.version found in current directory"
	echo "Quitting."
	exit 1
fi

VERSION=`cat ${BASE}/kubespray.version`
TMPDIR=`mktemp -d`

echo ""
echo "  [+] Downloading Kubespray ${VERSION} ..."
wget -q -O ${TMPDIR}/${VERSION}.tar.gz https://codeload.github.com/kubernetes-sigs/kubespray/tar.gz/${VERSION}

echo "  [+] Unpacking tarball ..."
tar -C ${TMPDIR} -xzf ${TMPDIR}/${VERSION}.tar.gz

KUBESPRAYDIR=$(dirname `find ${TMPDIR} -maxdepth 2 -name "README.md" | head -n1`)

chmod o-w ${KUBESPRAYDIR} ${BASE}

echo "  [+] Setting up Kubespray ..."
mkdir -p ${KUBESPRAYDIR}/inventory/merged
cp -rf ${KUBESPRAYDIR}/inventory/sample/group_vars ${KUBESPRAYDIR}/inventory/merged/

echo "  [+] Configuring Kubespray ..."
for f in `find ${KUBESPRAYDIR}/inventory/merged -type f -name "*.yml"`; do
	RELATIVE_FILE="${f/"${KUBESPRAYDIR}/inventory/merged/"/}"
	if [ -f "${RELATIVE_FILE}" ]; then
		if [ -s "$f" ]; then
			cp -f "${RELATIVE_FILE}" "$f"
		else
			echo ${TMPDIR}/yq m -i "$f" "${RELATIVE_FILE}"
			${TMPDIR}/yq m -i "$f" "${RELATIVE_FILE}"
		fi
	fi
done

cp -f ${BASE}/hosts.ini ${KUBESPRAYDIR}/inventory/merged/hosts.ini

echo "  [+] Configuring Ansible ..."
if [ -f ${BASE}/ansible.cfg ]; then
	export ANSIBLE_CONFIG="${BASE}/ansible.cfg"
fi

echo "  [+] Installing requirements ..."
pip install -r ${KUBESPRAYDIR}/requirements.txt

echo "  [+] Running playbook ..."
cd ${KUBESPRAYDIR}
ansible-playbook -i ${KUBESPRAYDIR}/inventory/merged/hosts.ini ${@}

echo "  [+] Cleaning up ..."
rm -rf ${TMPDIR}
echo ""
