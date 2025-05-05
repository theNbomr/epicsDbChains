#! /usr/bin/perl -w
#
#	This file is the forerunner to the dbScanChain tool. No longer useful.
#	(RN 2025-May-04)
#

use strict;

sub scanBack( $ );

my %scanSources;    # Each member is a list of records that are scanlink targets

my %scanTargets;    # Each member (key = target record) is a list of records that 
                    # have the key record as a scan link target (LNKn & FLNK fields)
                    
my %scanPeriodics;    # All records (key) that are scan periodic (.SCAN Value)

my %scanRates;

my %vmeRecords;     # All records that have TRVME DYTP field


$/ = '}';

    while( <> ){
    
        $_ =~ m/record\(.+,"(.+)"\)/;
        my $recName = $1;
        
        if( $_ =~ m/TRVME/ ){
            $_ =~ m/record\(.+,"(.+)"\)/;
            print "TRVME: $1\n";
            $vmeRecords{ $recName } = undef;
        }
        
        if( $_ =~ m/field\(SCAN,"([.0-9]+ second)"\)/g ){
            print "$recName SCAN:",$1,"\n";
            $scanPeriodics{ $recName } = $1;
        }

        if( my @lnks = $_ =~ m/field\(LNK[0-9],"(.+)"/g ){
            print "LNKs: ", scalar @lnks, "\n";
            # print $_,"\n";
            # print "\t: ", join( "\n\t: ", @lnks ), "\n";
            # print "\n====\n";
            push @{$scanTargets{ $recName }}, @lnks;
            foreach my $scanTarget ( @lnks ){
                $scanTarget =~ s/\.PROC$//;
                push @{ $scanSources{ $scanTarget } }, $recName;
            }
        }
        
        if( my $flnk = $_ =~ m/field\(FLNK,"(.+)"/g ){
            # print "FLNK:\n";
            # print $1,"\n";
            my $scanTarget = $1;
            $scanTarget =~ s/\.PROC//;
            push @{ $scanTargets{ $recName }}, $scanTarget;
        }
        
    }
    
    
    print "\n\n\n\n\nTARGETS:\n";
    foreach my $scanSource ( keys %scanTargets ){
        my $scanTargetRef = $scanTargets{ $scanSource };
        my @scanTargets = @{ $scanTargetRef }; 
        print "$scanSource :\n\t", join( ",\n\t", @scanTargets ), "\n";
    }
    
    print "VME Records\n\t", join( ",\n\t", keys %vmeRecords ), "\n";
    
    #
    #   Search all VME records for their SCAN source.
    #
    
    foreach my $vmeRecord ( keys %vmeRecords ){
        if( defined( $scanPeriodics{ $vmeRecord } ) ){
            print $vmeRecord, ".SCAN:\n\t", $scanPeriodics{ $vmeRecord };
        }
        if( exists( $scanSources{ $vmeRecord } ) ){
            print $vmeRecord, ".slnk: ";
            print "\n\t", join( ",\n\t", @{$scanSources{ $vmeRecord }} );
            
            foreach my $scanSource ( @{$scanSources{ $vmeRecord }} ){
                if( exists( $scanPeriodics{ $scanSource } ) ){
                    print " = ",$scanPeriodics{ $scanSource };
                }
                else{
                    scanBack( $vmeRecord );
                }
                print "\n";
            }
        }
    }
    
    
sub scanBack( $ ){

my $targetRec = shift;
    #
    # For the given record, recursively find all references within "FLNK"s and "LNKn"s 
    #
    foreach my $scanSource ( keys %scanSources ){
        my @scanTargets = @{ $scanSources{ $scanSource } };
        
        foreach my $scanTarget ( @scanTargets ){
            #
            #   
            #
            if( $scanTarget cmp $targetRec ){
                print "\n\tFound SCAN master for $targetRec: $scanTarget\n";
                if( $scanPeriodics{ $scanTarget } ){
                    $scanRates{ $targetRec } = $scanPeriodics{ $scanTarget };
                    print "$targetRec SCAN : $scanPeriodics{ $scanTarget }\n";
                    return $scanPeriodics{ $scanTarget };
                }
                else{
                    print "Recursive scan for $scanTarget chain head\n";
                    scanBack( $scanTarget );
                }
            }
        }
        return( undef );
    }
   
   
   return undef;
}


