#!/usr/bin/perl
#
# author: Patrick aka Jolly
#
# usage:
#			use keychaincredentials;
#			my $password = keychaincredentials::keychainitem('find-internet-password -s daw.apple.com');
#	
#			return $$item{'acct'}{'value'};

package keychaincredentials;

sub userAtDomain($)
{
	my ($domain) = @_;
	my $item = keychaincredentials::keychainitem('find-internet-password -s '.$domain);
	
	return $$item{'acct'}{'value'};
}

sub passwordForUserAtDomain($$)
{
	my ($username,$domain) = (@_);
	
	print STDERR "Username:\t$username\nDomain :\t$domain\n";
	my $item = keychaincredentials::keychainitem('find-internet-password -s '.$domain.' -a '.$username.' -g');
	
	return $$item{'password'}{'value'};
}

sub keychainitem($)
{
	my($argument) = (@_);
	
    open(KEYCHAIN,"security $argument 2>&1|") || die "can't create pipe for keychain"; 
    select(KEYCHAIN);
   	$/ = undef;
    my $output = <KEYCHAIN>;
   	close(KEYCHAIN);
   	select(STDOUT);

	#	print STDERR $output."\n";
	my %attributes;
	
	while( $output =~ /^\s*("[^"]+"|0x[\da-fA-F]+)\s*<(blob|timedate|(?:u|s)int(?:32|16|8))>=(.*)\s*$/mg )
	{
		my($name,$type,$values) = ($1,$2,$3);
		my $value,$blob;

		$name =~ s/^"(.*)"$/$1/;
		
		if( $values =~ m/^<NULL>$/ )
		{
			$value = undef;
		}
		elsif( $values =~ m/^(0x[a-fA-F\d]+)\s*(?:"(.*)"\s*)?$/ )
		{
			($value,$blob) = ($1,$2);
		}
		elsif( $values =~ m/^\s*"(.*)"\s*$/ )
		{
			$value = $1;
		}
		else
		{
			print STDERR "Weird keychain item attribute: $1 $2 $3\n";
		}
	
		$value =~ s{ (\\\d\d) }{ chr($1) }segx;
		$attributes{$name}= {'value' => $value , 'blob' => $blob, 'type'=> $type };
	}
	
	
	if( $output =~ m/password:\s*\"(.*?)\"$/m )
	{
		$attributes{password}{type}		= 'blob';
		$attributes{password}{value}	= $1;
	}

	return \%attributes;
}


1;
