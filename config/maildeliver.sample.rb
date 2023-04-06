#$mdfilter.deliver_proc = $mdfilter.method(:deliver_mh)
$mdfilter.filter_procs.push $mdfilter.method(:filter_spamc)