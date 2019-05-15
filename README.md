# kubespray-runner

## Creating a new project

Create an empty directory and cd into it.

### Add version file

Add the branch or tag of the kubespray repository you want to use.

```bash
echo release-2.10 > kubespray.version
```
### Add a hosts.ini file

Add a kubespray-based hosts.ini file and adjust to your liking ( take it from kubespray/inventory/sample/hosts.ini for example.

### Override group_vars

Create group_vars directory, only add the files you want to override from the official kubespray group_vars, and only add the variables you want to change:

```bash
mkdir -p group_vars/all
echo "loadbalancer_apiserver_localhost: true" > group_vars/all/all.yml
```

## Run kubespray-runner

docker run -it --rm -v `pwd`:/app -w /app verwilst/kubespray-runner:latest kubespray-runner.sh cluster.yml

### Add .ssh directory if needed

Add "-v ~/.ssh:/root/.ssh" to make sure your SSH keys work.
