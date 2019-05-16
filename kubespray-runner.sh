#!/bin/bash

if [ ! -f $PWD/kubespray.version ]; then
	echo "No kubespray.version found in current directory"
	echo "Quitting."
	exit 1
fi

VERSION=`cat $PWD/kubespray.version`

PLAYBOOK=${1:-cluster.yml}

TMPDIR=`mktemp -d`

if [ "${PLAYBOOK}" == "cluster.yml" ]; then
	APIHOST=`grep "\[kube-master\]" -A 1 ${PWD}/hosts.ini | tail -n1`

	ansible all -i ${PWD}/hosts.ini -a "uptime" &> ${TMPDIR}/stdout
        if [ $? -ne 0 ]; then
		cat ${TMPDIR}/stdout
                echo "Cluster not reachable. Quitting."
                exit 1
        fi
	echo "  [+] All hosts in cluster reachable."
fi

echo ""
while echo $agree | grep -ivE "^[yn]$" &> /dev/null; do 
	read -p "Ready to run Kubespray ${VERSION} on playbook $PLAYBOOK. Proceed? [Y/n] " agree
	agree=${agree:-Y}
	agree=${agree,,}
done

if [ "${agree}" == "n" ]; then
	echo "Quitting."
	exit 0
fi
echo ""

echo "  [+] Downloading Kubespray ${VERSION} ..."
wget -q -O ${TMPDIR}/${VERSION}.tar.gz https://codeload.github.com/kubernetes-sigs/kubespray/tar.gz/${VERSION}

echo "  [+] Unpacking tarball ..."
tar -C ${TMPDIR} -xzf ${TMPDIR}/${VERSION}.tar.gz

KUBESPRAYDIR=$(dirname `find ${TMPDIR} -maxdepth 2 -name "README.md" | head -n1`)

chmod o-w ${KUBESPRAYDIR} ${PWD}

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

cp -f ${PWD}/hosts.ini ${KUBESPRAYDIR}/inventory/merged/hosts.ini

echo "  [+] Configuring Ansible ..."
if [ -f ${PWD}/ansible.cfg ]; then
	cat ${PWD}/ansible.cfg >> ${KUBESPRAYDIR}/ansible.cfg
fi

echo "  [+] Installing requirements ..."
pip install -r ${KUBESPRAYDIR}/requirements.txt

echo "  [+] Running $PLAYBOOK ..."
ansible-playbook -i ${KUBESPRAYDIR}/inventory/merged/hosts.ini ${KUBESPRAYDIR}/$PLAYBOOK

echo "  [+] Cleaning up ..."
rm -rf ${TMPDIR}
echo ""
