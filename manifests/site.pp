# Lookup classes to include from hiera
lookup('classes', Array[String], 'unique').include


# Example for assigning variables to nodes by node name or other rules
# - node-scope variables must be set BEFORE the hiera lookup for classes, so comment out the above lookup to use rules like these examples
# - When managing many nodes, it's more convenient to use an [ENC](https://github.com/southalc/enc)
########################################################################
# if $::trusted['certname'] == 'jenkins.example.com' {
#   $_role = 'jenkins'
# }
# # Set the 'win10_dev' role for all Windows 10 machines determined by facts and hostname
# else (($::facts['os']['family'] == 'windows') and ($::facts['os']['release']['major'] == '10')) and ($::hostname =~ /^dev(.+)/) {
#   $_role = 'win10_dev'
# }
# 
# # Use '$_role' as a node-scope variable and include classes from hiera
# node default {
#   $role = $_role
#   lookup('classes', Array[String], 'unique').include
# }
