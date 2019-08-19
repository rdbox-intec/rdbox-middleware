# rdbox_middleware

## About rdbox_middleware

`rdbox_middleware` is a middleware for RDBOX. It can be classified roughly into three roles.

### Dependency Injection

Switch the role of Raspberry Pi based on the configuration file.

1.  RDBOX(Master)
2.  RDBOX(Slave)
3.  RDBOX(VPNBridge)
4.  other(Robot, IoT equipment, Workstation, etc.)

### Network management

Controls the boot order of hostapd (access point) and wpa_supplicant (client).

### command line interface for RDBOX

Please refer to `rdbox_cli`.

* * *

## rdbox_cli

### About rdbox_cli

`rdbox_cli` is a command line interface for RDBOX. You can execute various operations and get information of RDBOX. For example, you can get a list of nodes, IP address, etc. in an optimal format for RDBOX.

```bash
$ rdbox_cli get node -f ansible
[edge]
rdbox-master-00            ansible_host=192.168.179.1    ansible_python_interpreter=/usr/bin/python3
rdbox-slave-01             ansible_host=192.168.179.52   ansible_python_interpreter=/usr/bin/python3
rdbox-vpnbridge-00         ansible_host=192.168.179.238  ansible_python_interpreter=/usr/bin/python3

[hq]
rdbox-k8s-master           ansible_host=192.168.179.2    ansible_python_interpreter=/usr/bin/python3
rdbox-k8s-worker-cloud-01  ansible_host=192.168.179.201  ansible_python_interpreter=/usr/bin/python3
rdbox-k8s-worker-cloud-02  ansible_host=192.168.179.115  ansible_python_interpreter=/usr/bin/python3
```

In this document, we run the initial process for using rdbox_cli and some of the commands.

#### Setup (only run for the first time)

1.  Ensure that login RDBOX(Master) by ssh.
    ```bash
    $ ssh ubuntu@rdbox-master-00
    ```
2.  Initialize rdbox_cli. It will be successful if the terminal displays "[rdbox_cli] Success completed." In case of other display, please re-execute.
    ```bash
    $ sudo rdbox_cli init onprem
    :
    [omit] 
    :
    [rdbox_cli] Success completed.
    ```
3.  Initialize helm. (Helm is a package manager for Kubernetes, it helps to add various functions to RDBOX, see [Helm - The Kubernetes Package Manager](https://helm.sh/) for details)
    ```bash
    $ kubectl apply -f https://raw.githubusercontent.com/Azure/helm-charts/master/docs/prerequisities/helm-rbac-config.yaml
    $ helm init --service-account tiller --node-selectors "beta.kubernetes.io/arch"="amd64"
    ```
4.  Activate the function so that you can use Kubernetes' Ingress with RDBOX.
    ```bash
    $ sudo rdbox_cli enable k8s_external_svc
    :
    [omit] 
    :
    [rdbox_cli] Success completed
    ```

#### Examples

#### Get node list in ansible Inventry file format

1 . Execute command `rdbox_cli get node -f ansible`.

```bash
$ rdbox_cli get node -f ansible
[edge]
rdbox-master-00            ansible_host=192.168.179.1    ansible_python_interpreter=/usr/bin/python3
rdbox-slave-01             ansible_host=192.168.179.52   ansible_python_interpreter=/usr/bin/python3
rdbox-vpnbridge-00         ansible_host=192.168.179.238  ansible_python_interpreter=/usr/bin/python3

[hq]
rdbox-k8s-master           ansible_host=192.168.179.2    ansible_python_interpreter=/usr/bin/python3
rdbox-k8s-worker-cloud-01  ansible_host=192.168.179.201  ansible_python_interpreter=/usr/bin/python3
rdbox-k8s-worker-cloud-02  ansible_host=192.168.179.115  ansible_python_interpreter=/usr/bin/python3
```

#### Enable temporary cache registry.

As an example, in RDBOX we will describe a method for activating temporary container cache registry. We provide a transparent cache service that is transparent to users in RDBOX network.
You can get the following effects.

-   The effect that each node can reduce the traffic volume than downloading a container image from the Docker Hub via the Internet.
-   Effects that can reduce the download time of container images.
-   Effects that can also be used as a temporary container registry.  

Please note that data persistence is not guaranteed.

1.  Activate temporary container cache registry (It will take some time to complete setup.)

    ```bash
    $ sudo rdbox_cli enable temporary_cache_registry
    :
    [omit]
    :
    [rdbox_cli] Success completed.
    ```

2.  Perform network tests. Please do it after a few minutes after `1. Activate temporary container cache registry`. Issue a GET request to the domain of "<https://cache-registry.rdbox.lan/v2/_catalog">. Please confirm that response message `{"repositories": []}` comes back.
    ```bash
    $ curl https://cache-registry.rdbox.lan/v2/_catalog
    {"repositories": []}
    ```
3.  Execute Docker Pull at an arbitrary RDBOX.
    ```bash
    $ docker pull centos:7
    ```
4.  Execute the same curl command. Then, the image downloaded with "3." Is displayed.
    ```bash
    $ curl https://cache-registry.rdbox.lan/v2/_catalog
    {"repositories": [centos/7]}
    ```
5.  Thereafter, when pulling the same image, the temporary container cache registry is used preferentially. When deploying images to a large number of robots, we can efficiently distribute images. By pre-caching the image.

#### Disable temporary cache registry.

If you do not need this function, please disable the function.

```bash
$ rdbox_cli disable temporary_cache_registry
:
[omit]
:
[rdbox_cli] Success completed.
```

## License

MIT - see the [LICENSE](./LICENSE) file for details.
