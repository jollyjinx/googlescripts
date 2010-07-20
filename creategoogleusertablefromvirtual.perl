#!/bin/perl
#
#
# creategoogleusertable from virtual
#
# creates a usertable and an aliastable from a postfix virtual table
#

use JNX::Configuration;


my %commandlineoption = JNX::Configuration::newFromDefaults( {																	
																	'domainname'				=>	['example.com','string'],
															 }, __PACKAGE__ );


use strict;

my %users;

while( my $line = <STDIN> )
{
	chomp $line;
	$line = lc $line;
	
	if( $line =~ m/^([a-z\d\_\-\+\.]+)\@$commandlineoption{domainname}\s+([a-z\d\_\-\+\.]+)\@$commandlineoption{domainname}\s*$/ )
	{
		my($aliasname,$username) = ($1,$2);
		
		
		if( $aliasname =~ /^([a-z]+)\.([a-z]+)$/ )
		{
			my( $firstname, $lastname ) = ($1,$2);
			
			if( !defined $users{$username}{lastname} && !defined $users{$username}{firstname} )
			{
				$users{$username}{firstname}	= $firstname;
				$users{$username}{lastname}		= $lastname;
			}
		}
		$users{$username}{aliases}{$aliasname} = 1;
	}
}


print "Usertable:\n";

for my $username (sort{ $users{$a}{lastname} cmp $users{$b}{lastname} || $users{$a}{firstname} cmp $users{$b}{firstname} }(keys %users))
{	
	print	join("\t", ($username,ucfirst($users{$username}{firstname}),ucfirst($users{$username}{lastname}),randompassword()) ) . "\n";
}



print "Aliases used\n";
for my $username (sort{ $users{$a}{lastname} cmp $users{$b}{lastname} || $users{$a}{firstname} cmp $users{$b}{firstname} }(keys %users))
{	
	delete $users{$username}{aliases}{$username};
	
	my @aliases = (sort(keys(%{$users{$username}{aliases}})));

	if( @aliases > 0 )
	{
		print "\n\n$username\n".join("\n",@aliases)."\n";
	}
}

exit;



sub randompassword()
{
	local $/ = undef;
	open(FILE,"/dev/random")	|| die __LINE__."Can't open /dev/random"; 
	
	my $randomdata;
	
	if( 8 != read(FILE,$randomdata,8) )
	{
		die __LINE__."Can't read /dev/random";
	}
	
	close(FILE);
	
	return unpack('H*',$randomdata);
}