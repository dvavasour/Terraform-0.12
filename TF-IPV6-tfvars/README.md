Terraform Demo Notes

- This code will run up an instance running in a IPV6 VPC etc
- The created SG allows SSH but not HTTP - this needs adding
- Install Busybox "yum install -y busybox"
- Put a message in index.html
- Start with `busybox httpd -f -vv` - the `-f` keeps it running in the foreground rather than demonising and the `-vv` will show the requests being made

