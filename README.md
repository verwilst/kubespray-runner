# kubespray-runner

## Create a new deployment

```bash
wget https://github.com/kubernetes-sigs/kubespray/archive/release-2.9.tar.gz
tar -xvzf release-2.9.tar.gz kubespray-release-2.9/inventory/sample/
mv kubespray-release-2.9/inventory/sample/ myproject
echo "RELEASE=release-2.9" > myproject/.kubespray-runner.yml
```
