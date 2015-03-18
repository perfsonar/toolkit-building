# perfSONAR Toolkit Building

This repository contains script to build the NetInstall and Full DVD ISOs of the Toolkit distribution.

##Updating the kickstarts
The kickstart files are located under the *kickstarts* directory. If you make any changes to the files, run the following command before performing a build:

```bash
./scripts/build_patches
```


##Building the NetInstall

The basic process is as follows:

```bash
./scripts/build_netinstall --arch <i386|x86_64>
```

For more detailed instructions see https://github.com/perfsonar/project/wiki/CentOS-Build-Instructions#customizing-the-toolkit-netinstall

##Building the Full DVD
See https://github.com/perfsonar/project/wiki/CentOS-Full-DVD-Build-Instructions
