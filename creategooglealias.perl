#!/bin/perl
#
#
#	
#
use keychaincredentials;
use JNX::Configuration;


my %commandlineoption = JNX::Configuration::newFromDefaults( {																	
																	'googleserver'				=>	['https://www.google.com','string'],
																	'adminname'					=>	['admin','string'],
																	'domainname'				=>	['example.com','string'],
																	'aliasuser'					=>	['john','string'],
																	'cookiejar'					=>	['cookiejar','string'],
																	'curlcommand'				=>	['sleep 1;curl -D - --cookie cookiejar --cookie-jar cookiejar -H "Content-type=application/x-www-form-urlencoded"','string'],
															 }, __PACKAGE__ );


use strict;

$commandlineoption{curlcommand}	.= ' --cookie '.$commandlineoption{cookiejar}.' --cookie-jar '.$commandlineoption{cookiejar}.' ';
unlink($commandlineoption{cookiejar});


my @aliases;


print "Alias (Ctrl-D to exit) :";

while( $_ = <STDIN> )
{
	my $alias = $_;
	
	chomp $alias;
	
	$alias = lc $alias;
	$alias =~ s/\s+//g;
	
	next if !length($alias);
	
	push(@aliases,$alias);
	print "\nAlias (Ctrl-D to exit) :";
}

print "Creating aliases for: ".join(', ',@aliases)."\n";


my $adminpassword	= undef;
my ($dsh,$galx,$ltmpl);
my $redirecturl;
my $timenow;



foreach my $alias (@aliases)
{
	print "Creating Alias: $alias\n";
		
	while( !defined($adminpassword) )
	{
		$adminpassword = keychaincredentials::passwordForUserAtDomain($commandlineoption{adminname}.'@'.$commandlineoption{domainname},'www.google.com');

		next if !defined($adminpassword);
		
		
		my $htmloutput = `$commandlineoption{curlcommand} "$commandlineoption{googleserver}/a/$commandlineoption{domainname}/ServiceLogin"`;
		
		if( 1 != ($htmloutput =~ m#<input\s+type="hidden"\s+name="dsh"\s+id="dsh"\s+value="(.*?)"\s/>#io) )
		{
			print $htmloutput;
			die __LINE__."Can't find dsh in pre-login\n";
		}
		$dsh = $1;
		# print "DSH: $dsh\n";
		
		if( 1 != ($htmloutput =~ m#<input\s+type="hidden"\s+name="GALX"\s+value="(.*?)"\s/>#io) )
		{
			print $htmloutput;
			die __LINE__."Can't find GALX in pre-login\n";
		}
		$galx = $1;
		# print "GALX: $galx\n";
		
		
		{
			my $dashboardurl = $commandlineoption{googleserver}."/a/cpanel/$commandlineoption{domainname}/Dashboard";
			my $htmloutput = `$commandlineoption{curlcommand}  -d "dsh=$dsh" -d "GALX=$galx" -d "Passwd=$adminpassword" -d "Email=$commandlineoption{adminname}" -d "PersistentCookie=yes" -d "rmShown=1" -d "asts=" -d "signIn=Sign in" -d "continue=$dashboardurl" -d "followup=$dashboardurl" "$commandlineoption{googleserver}/a/$commandlineoption{domainname}/LoginAction2?service=CPanel"`;
		
			if( 1 != ($htmloutput =~ m#The document has moved <A HREF="(.*?)">here</A>#io) )
			{
				print $htmloutput;
				die __LINE__."Can't find redirect on login\n";
			}
			$redirecturl = $1;
			print "Redirect1 url = $1\n";
		}
		
		{
			my $htmloutput = `$commandlineoption{curlcommand} "$redirecturl"`;

			if( 1 != ($htmloutput =~ m#The document has moved <A HREF="(.*?)">here</A>#io) )
			{
				print $htmloutput;
				die __LINE__."Can't find redirect on 1stredirect\n";
			}
			$redirecturl = $1;
			print "Redirect2 url = $1\n";
		}

		{
			my $htmloutput = `$commandlineoption{curlcommand} "$redirecturl"`;
			
			
			if( $htmloutput !~ m#<li\s+class="(?:selected)?"\s+id="CPanelMenuUsers">#io) 
			{
				print $htmloutput;
				die __LINE__."Seems to be not logged in as admin on Dashboard (no menu users)\n";
			}
			if( 1 != ($htmloutput =~ m#<input\s+type="hidden"\s+name="at"\s+value="(.*?)">#io) )
			{
				print $htmloutput;
				die __LINE__."Seems to be not logged in on Dashboard (no time)\n";
			}
			$timenow=$1;
		}

		{
			my $htmloutput = `$commandlineoption{curlcommand}	"$commandlineoption{googleserver}/a/cpanel/$commandlineoption{domainname}/Users"`;
			
			
			if( $htmloutput !~ m#<li\s+class="(?:selected)?"\s+id="CPanelMenuUsers">#io) 
			{
				print $htmloutput;
				die __LINE__."Seems to be not logged in on Dashboard\n";
			}
			if( 1 != ($htmloutput =~ m#<input\s+type="hidden"\s+name="at"\s+value="(.*?)">#io) )
			{
				print $htmloutput;
				die __LINE__."Seems to be not logged in on Dashboard (no time)\n";
			}
			$timenow=$1;
		}
		{
			my $htmloutput = `$commandlineoption{curlcommand}	"$commandlineoption{googleserver}/a/cpanel/$commandlineoption{domainname}/User?userEmail=$commandlineoption{aliasuser}%40$commandlineoption{domainname}"`;
			
			
			if( $htmloutput !~ m#<li\s+class="(?:selected)?"\s+id="CPanelMenuUsers">#io) 
			{
				print $htmloutput;
				die __LINE__."Seems to be not logged in on Dashboard\n";
			}
			if( 1 != ($htmloutput =~ m#<input\s+type="hidden"\s+name="at"\s+value="(.*?)">#io) )
			{
				print $htmloutput;
				die __LINE__."Seems to be not logged in on Dashboard (no time)\n";
			}
			$timenow=$1;
			print "Login OK\n";
		}
	}
	
	#
	# per alias now that we are logged in
	#
	{
		my $options = join(' ',split(/\n\s+/,'-d "at='.$timenow.'"
												-d "Email='.$commandlineoption{aliasuser}.'@'.$commandlineoption{domainname}.'"
												-d "userName='.$commandlineoption{aliasuser}.'@'.$commandlineoption{domainname}.'"
												-d "userEmail='.$commandlineoption{aliasuser}.'@'.$commandlineoption{domainname}.'"
												-d "nameIsSet=false"
												-d "password.isSet=false"
												-d "changename=leavealone"
												-d "list1IsSet=false"
												-d "list2IsSet=false"
												-d "list3IsSet=false"
												-d "nicknameIsSet=true"
												-d "action.save=true"
												-d "password.newPassword.alpha="
												-d "password.newPassword.beta="
												-d "nicknameToRemove="
												-d "addNickname='.$alias.'"'));
		
	
		my $htmloutput = `$commandlineoption{curlcommand} $options	"$commandlineoption{googleserver}/a/cpanel/$commandlineoption{domainname}/UserAction"`;
		
		
		if( $htmloutput !~ m#<li\s+class="(?:selected)?"\s+id="CPanelMenuUsers">#io) 
		{
			print $htmloutput;
			die __LINE__."Seems to be not logged in on Dashboard\n";
		}
		if( 1 != ($htmloutput =~ m#<input\s+type="hidden"\s+name="at"\s+value="(.*?)">#io) )
		{
			print $htmloutput;
			die __LINE__."Seems to be not logged in on Dashboard (no time)\n";
		}
		$timenow=$1;
		print "$alias - OK\n";
	}
}				
		
print "Aliases created\n";

unlink($commandlineoption{cookiejar});

exit;

