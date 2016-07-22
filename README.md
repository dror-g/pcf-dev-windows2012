Forked into a full repo from this gist: https://gist.github.com/sneal/b3db4d2fdbd3c4edff2d

Updated to work on Windows w/Vagrant as the pre-load script was escaped for sh. This should work on either.

Pre-reqs
--------
* https://github.com/pivotal-cf/pcfdev installed
* ssh/scp available on command line (for Windows too)

Running
-------
    vagrant up

Deploying sample app
-------------------
    cf login -a https://api.local.pcfdev.io --skip-ssl-validation
    git clone https://github.com/cloudfoundry-incubator/NET-sample-app.git
    cd NET-sample-app
    cf push environment -s windows2012R2 -b binary_buildpack -p ./ViewEnvironment/
