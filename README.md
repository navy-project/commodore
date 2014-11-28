*To see get a runnning navy project host, look at the vagrantboot repository*


# Commodore

Commodore processes convoy requests and sets the desired state of the navy accordingly.

It watches changes to:

/navy/convoys/:id/manifest/desired
/navy/convoys/:id/manifest/actual

Manifest.yml stored in the keys

Commodore then puts
/navy/containers/:containername/desired

What is stored in the key is

{
  :state => running | completed
  :dependencies => [:list, :of, :containers],
  :specification => {
    :convoyid => ..
    :name => ...simple app name.
    :image => .
    :sha => ..
    :links => ...
    :...
  }
}


dependencies are satisfied in contents of /navy/containers/<depname>/actual == desired
specification contains all required facts to construct a running container.  no need to consult dependencies etc..
