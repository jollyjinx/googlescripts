#!/bin/perl

use keychaincredentials;

my $adminname 		= 'jolly';
my $domainname		= 'jinx.eu';

my $aliasuser		= 'robot';


$curlcmd		= 'sleep 1;curl -D - --cookie cookiejar --cookie-jar cookiejar -H "Content-type=application/x-www-form-urlencoded" ';
$googleserver	= 'https://www.google.com';

unlink('cookiejar');


my @aliases;


print "Alias (Ctrl-D to exit) :";

while( $_ =<> )
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
my $dsh,$galx,$ltmpl;
my $redirecturl;




foreach my $alias (@aliases)
{
	print "Creating Alias: $alias\n";
		
	while( !defined($adminpassword) )
	{
		$adminpassword = keychaincredentials::passwordForUserAtDomain($adminname.'@'.$domainname,'www.google.com');

		next if !defined($adminpassword);
		
		
		my $htmloutput = `$curlcmd "$googleserver/a/$domainname/ServiceLogin"`;
		
		if( 1 != ($htmloutput =~ m#<input\s+type="hidden"\s+name="dsh"\s+id="dsh"\s+value="(.*?)"\s/>#io) )
		{
			print $htmloutput;
			die __LINE__."Can't find dsh in pre-login\n";
		}
		$dsh = $1;
		print "DSH: $dsh\n";
		
		if( 1 != ($htmloutput =~ m#<input\s+type="hidden"\s+name="GALX"\s+value="(.*?)"\s/>#io) )
		{
			print $htmloutput;
			die __LINE__."Can't find GALX in pre-login\n";
		}
		$galx = $1;
		print "GALX: $galx\n";
		
		
		{
			my $dashboardurl = $googleserver."/a/cpanel/$domainname/Dashboard";
			my $htmloutput = `$curlcmd  -d "dsh=$dsh" -d "GALX=$galx" -d "Passwd=$adminpassword" -d "Email=$adminname" -d "PersistentCookie=yes" -d "rmShown=1" -d "asts=" -d "signIn=Sign in" -d "continue=$dashboardurl" -d "followup=$dashboardurl" "$googleserver/a/$domainname/LoginAction2?service=CPanel"`;
			# my $htmloutput = `$curlcmd -d "dsh=$dsh" -d "GALX=$galx" -d "Passwd=$adminpassword" -d "Email=$adminname" -d "PersistentCookie=no" "$googleserver/a/$domainname/LoginAction2"`;
					print $htmloutput;
		
			if( 1 != ($htmloutput =~ m#The document has moved <A HREF="(.*?)">here</A>#io) )
			{
				print $htmloutput;
				die __LINE__."Can't find redirect on login\n";
			}
			$redirecturl = $1;
			print "Redirect1 url = $1\n";
		}
		
		{
			my $htmloutput = `$curlcmd "$redirecturl"`;

			if( 1 != ($htmloutput =~ m#The document has moved <A HREF="(.*?)">here</A>#io) )
			{
				print $htmloutput;
				die __LINE__."Can't find redirect on 1stredirect\n";
			}
			$redirecturl = $1;
			print "Redirect2 url = $1\n";
		}

		{
			my $htmloutput = `$curlcmd "$redirecturl"`;
			
			
			if( $htmloutput !~ m#<li\s+class="(:?selected)?"\s+id="CPanelMenuUsers">#io) 
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
			print "Time now: $timenow\n";
		}

		{
			my $htmloutput = `$curlcmd	"https://www.google.com/a/cpanel/$domainname/Users"`;
			
			
			if( $htmloutput !~ m#<li\s+class="(:?selected)?"\s+id="CPanelMenuUsers">#io) 
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
			print "Time now: $timenow\n";
			print "OK\n";
		}
		{
			my $htmloutput = `$curlcmd	"https://www.google.com/a/cpanel/$domainname/User?userEmail=$aliasuser%40$domainname"`;
			
			
			if( $htmloutput !~ m#<li\s+class="(:?selected)?"\s+id="CPanelMenuUsers">#io) 
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
			print "Time now: $timenow\n";
			print "OK\n";
		}
	}
	
	#
	# per alias now that we are logged in
	#
	{
		my $options = join(' ',split(/\n\s+/,'-d "at='.$timenow.'"
												-d "Email='.$aliasuser.'@'.$domainname.'"
												-d "userName='.$aliasuser.'@'.$domainname.'"
												-d "userEmail='.$aliasuser.'@'.$domainname.'"
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
		
	
		my $htmloutput = `$curlcmd $options	"https://www.google.com/a/cpanel/jinx.eu/UserAction"`;
		
		
		if( $htmloutput !~ m#<li\s+class="(:?selected)?"\s+id="CPanelMenuUsers">#io) 
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
exit;

