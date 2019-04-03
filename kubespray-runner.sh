#!/bin/bash -e

if [ ! -f $PWD/.kubespray-runner.yml ]; then
	echo "No .kubespray-runner.yml found in current directory"
	echo "Quitting."
	exit 1
fi

source $PWD/.kubespray-runner.yml || exit 1

PLAYBOOK=${1:-cluster.yml}

echo ""
while echo $agree | grep -ivE "^[yn]$" &> /dev/null; do 
	read -p "Ready to run Kubespray $RELEASE on playbook $PLAYBOOK. Proceed? [Y/n] " agree
	agree=${agree:-Y}
	agree=${agree,,}
done

if [ "${agree}" == "n" ]; then
	echo "Quitting."
	exit 0
fi
echo ""

TMPDIR=`mktemp -d`

echo "  [+] Downloading Kubespray ${RELEASE} ..."
wget -q -O ${TMPDIR}/${RELEASE}.tar.gz https://codeload.github.com/kubernetes-sigs/kubespray/tar.gz/${RELEASE}

echo "  [+] Unpacking tarball ..."
tar -C ${TMPDIR} -xzf ${TMPDIR}/${RELEASE}.tar.gz

KUBESPRAYDIR=$(dirname `find ${TMPDIR} -maxdepth 2 -name "README.md" | head -n1`)

echo "  [+] Configuring Kubespray ..."
rm -rf ${KUBESPRAYDIR}/inventory/local
cp -rf ${PWD} ${KUBESPRAYDIR}/inventory/local

if [ -f ${KUBESPRAYDIR}/inventory/local/ansible.cfg ]; then
	cat ${KUBESPRAYDIR}/inventory/local/ansible.cfg >> ${KUBESPRAYDIR}/ansible.cfg
fi

echo "  [+] Running $PLAYBOOK"
ansible-playbook -i ${KUBESPRAYDIR}/inventory/local/hosts.ini ${KUBESPRAYDIR}/$PLAYBOOK -vvv


echo "  [+] Cleaning up ..."
rm -rf ${TMPDIR}

echo ""

