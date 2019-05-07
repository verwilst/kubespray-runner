#!/bin/bash -e

if [ ! -f $PWD/.kubespray-runner.yml ]; then
	echo "No .kubespray-runner.yml found in current directory"
	echo "Quitting."
	exit 1
fi

source $PWD/.kubespray-runner.yml || exit 1

PLAYBOOK=${1:-cluster.yml}

if [ "${PLAYBOOK}" == "cluster.yml" ]; then
	APIHOST=`grep api001 -m 1 $PWD/hosts.ini`
	ssh core@${APIHOST} test -f /opt/bin/kubectl
	if [ $? -eq 0 ]; then
		echo "Cluster already exists. Quitting."
		exit 1
	fi
fi

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

echo "  [+] Installing requirements ..."
pip install -r ${KUBESPRAYDIR}/requirements.txt

echo "  [+] Running $PLAYBOOK ..."
ansible-playbook -i ${KUBESPRAYDIR}/inventory/local/hosts.ini ${KUBESPRAYDIR}/$PLAYBOOK

echo "  [+] Cleaning up ..."
rm -rf ${TMPDIR}

echo ""

