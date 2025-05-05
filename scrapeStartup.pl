#! /usr/bin/perl -w
use strict;



my @startups;
my @dbs;


    while( <> ){
        # Skip comment lines
        if( $_ =~ m/^[\s]*#/ ){
            next;
        }
        
        
        if( $_ =~ m/dbLoadRecords/ ){
            # print $_;
            $_ =~ m/"([^"]+)/;
            my $db = $1;
            $db =~ s/^(.+[\/])//;
            # print $db,"\n";
            push @dbs, "rsync -vaz icdeb8:/usr1/isac/db/".$db." .";
        }
    }
    
    print join( "\n", @dbs ), "\n";
    
    
    
