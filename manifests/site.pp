# Include classes from hiera lookup, enabling specific exclusions
$hiera_classes          = lookup('classes',          Array[String], 'unique', [])
$hiera_class_exclusions = lookup('class_exclusions', Array[String], 'unique', [])
include  [ $hiera_classes - $hiera_class_exclusions ]

# Example for node classification with node scope variables from the manifest
# - Set node-scope variables BEFORE a hiera lookup for classes
# - I find it more convenient to use an [ENC](https://github.com/southalc/enc)
########################################################################
# if $::trusted['certname'] == 'jenkins.example.com' {
#   $_role = 'jenkins'
# }
# Set the 'win10_dev' role for all Windows 10 machines determined by facts and hostname
# - You could also do this by referencing facts in hiera.yaml
# else (($::facts['os']['family'] == 'windows') and ($::facts['os']['release']['major'] == '10')) and ($::hostname =~ /^dev(.+)/) {
#   $_role = 'win10_dev'
# }
# 
# Use '$_role' as a node-scope variable and include classes from hiera
# node default {
#   $role = $_role
#   lookup('classes', Array[String], 'unique').include
# }
