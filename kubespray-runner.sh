#!/bin/bash

if [ ! -f $PWD/.kubespray-runner.yml ]; then
	echo "No .kubespray-runner.yml found in current directory"
	echo "Quitting."
	exit 1
fi

source $PWD/.kubespray-runner.yml || exit 1

PLAYBOOK=${1:-cluster.yml}

TMPDIR=`mktemp -d`

echo "  [+] Installing dependencies"
wget https://github.com/mikefarah/yq/releases/download/2.3.0/yq_linux_amd64 -O ${TMPDIR}/yq
chmod +x ${TMPDIR}/yq

which ansible &> /dev/null
if [ $? -ne 0 ]; then
        apt-get install -y --no-install-recommends python-pip
        pip install ansible
fi

if [ "${PLAYBOOK}" == "cluster.yml" ]; then
	APIHOST=`grep "\[kube-master\]" -A 1 ${PWD}/hosts.ini | tail -n1`

	ansible all -i ${PWD}/hosts.ini -a "uptime" &> ${TMPDIR}/stdout
        if [ $? -ne 0 ]; then
		cat ${TMPDIR}/stdout
                echo "Cluster not reachable. Quitting."
                exit 1
        fi
	echo "  [+] All hosts in cluster reachable."

	ansible ${APIHOST} -i ${PWD}/hosts.ini -a "test -f /usr/bin/kubectl" &> ${TMPDIR}/stdout
	if [ $? -eq 0 ]; then
		cat ${TMPDIR}/stdout
		echo "Cluster already exists. Quitting."
		exit 1
	fi
	echo "  [+] New cluster."
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

echo "  [+] Downloading Kubespray ${RELEASE} ..."
wget -q -O ${TMPDIR}/${RELEASE}.tar.gz https://codeload.github.com/kubernetes-sigs/kubespray/tar.gz/${RELEASE}

echo "  [+] Unpacking tarball ..."
tar -C ${TMPDIR} -xzf ${TMPDIR}/${RELEASE}.tar.gz

KUBESPRAYDIR=$(dirname `find ${TMPDIR} -maxdepth 2 -name "README.md" | head -n1`)

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
