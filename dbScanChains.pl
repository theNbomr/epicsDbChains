#! /bin/perl -w

use strict;

#
#   SCAN chain conceptual definitions for this code:
#
#       scanChainHead  - record with SCAN = Periodic ( "x.x second" ) and at least one non-empty LNKx or FLNK field
#
#       scanChainNode  - record with no SCAN Periodic value, and both a FLNK/LNKx, 
#                        and another record with this record as the target of a FLNK or LNKx link
#
#       scanChainLeaf  - record with no forward links and at least one 
#                        scan link from another record (FLNK or LNKx) and SCAN field empty
#
#   Example relationships:
#
#   scanChainHead --> scanChainNode --> scanChainLeaf
#   scanChainHead --> scanChainNode --> scanChainNode --> scanChainNode --> scanChainLeaf
#   scanChainHead --> scanChanLeaf
#   scanChainLeaf
#
#
#

use constant    SCAN_CHAIN_HEAD   =>  1;
use constant    SCAN_CHAIN_NODE   =>  2;
use constant    SCAN_CHAIN_LEAF   =>  3;

my @dtypes = ( "TRVME",
               "OMS VME58"
             );
             
my @epicsRecords;
my @scanChainHeads;
my @scanChainNodes;
my @scanChainLeafs;

my $dtype;

$/ = '}';

    while( <> ){
    
        $_ =~ m/record\(.+,"(.+)"\)/;
        my $recName = $1;
        
        #
        #   field(DTYP,"TRVME")
        #
        if( $_ =~ m/field\(DTYP,"([^"]+)"\)/ ){
            $dtype = $1;
            # print "Name: $recName, DTYP: $dtype\n";
        }
        else{
            # print "Name: $recName, DTYP: 'Soft Channel'\n";
        }
        
        my $rec = epicsRecord->new( name => $recName );
        $rec->parse( $_ );
        push @epicsRecords, $rec;
        
        foreach my $dtype ( @dtypes ){
            if( $_ =~ m/$dtype/ ){
                $rec->property( "chain", SCAN_CHAIN_LEAF );
                push @scanChainLeafs, $rec;
                last;
            }
        }
    }
    
    foreach my $epicsRecord ( @epicsRecords ){
        my @links = $epicsRecord->links();
        if( @links ){
#             # print $epicsRecord->name(),"\n";
#             foreach my $linkField ( @links ){
#                 # print "\t", $linkField, " : ", $epicsRecord->link( $linkField ),"\n";
#             }
            
            my $scan = $epicsRecord->scan();
            if( defined( $scan ) ){
                push @scanChainHeads, $epicsRecord;
                $epicsRecord->property( "chain", SCAN_CHAIN_HEAD );
            }
            else{
                push @scanChainNodes, $epicsRecord;
            }
        }
    }

    print "Scanning links to ";
    foreach my $scanChainLeaf ( sort @scanChainLeafs ){
        my $leafName = $scanChainLeaf->name();
        print "\r==> $leafName    ";
        
        foreach my $scanChainNode ( @scanChainNodes ){
            my $nodeName = $scanChainNode->name();
            foreach my $linkField ( $scanChainNode->links() ){
                my $linkTarget = $scanChainNode->link( $linkField );
                $linkTarget =~ s/\.PROC//;
                # print "$linkTarget ";
                # print "Leaf: $leafName, Node: $nodeName $linkField, Link: $linkTarget\n";
                # exit;
                if( $linkTarget eq $leafName ){
                    print "\nAdding slnk $nodeName\.$linkField to leaf $leafName\n";
                    $scanChainLeaf->slnks( $scanChainNode->{ $linkField } );
                    $scanChainLeaf->property( "chain", SCAN_CHAIN_LEAF );
                }
            }
        }
    }
    
    foreach my $leafRecord ( @scanChainLeafs ){
        # print $leafRecord->name(), "\n\t", join( ",\n\t", $leafRecord->fields() ), "\n";
    }
    
1;    
    
package epicsRecord;

sub new {
my $proto = shift;
my $class = ref( $proto ) || $proto;
my $self = {};


    bless $self, $class;

    my %params = @_;
    foreach my $key ( keys %params ){
        my $value = $params{ $key };
        $self->{ $key } = $value;
        print "Key: $key, Value: $value\n";
        # exit;
    }
    return $self;
}


sub parse {
my $self = shift;
my $record = shift;

my $key;
my $value;

    # print $record;
    my @fields = $record =~ m/field\(([A-Za-z0-9]+),"([^"]+)"/g;
    # print join( " : ", @fields ), "\n";
    
    while( ( $key, $value ) = splice( @fields, 0, 2 ), defined( $key ) && defined( $value ) ){
#    while( ( $key, $value ) = splice( @fields, 0, 2 ), defined( $key ) ){
        # print "Key: $key, Val: $value\n";
        $self->{ $key } = "$value";
    }
}

sub name {
my $self = shift;

    # print "epicsRecord::name() ";
    
    if( defined( $self->{ name } ) ){
        # print "name found\n";
        return $self->{ name };
    }
    elsif( my $name = shift ){
        # print "name supplied\n";
        $self->{ name } = $name;
        return( $name );
    }
    # print "No action\n";
    return undef;
}


#
#   Get the specified property, or if a value is supplied, 
#   set the property to the specified value.
#
sub property {
my $self = shift;
my $key;
my $value;

    if( @_ ){
        $key = shift;
        if( @_ ){               # Set the property
            $value = shift;
            $self->{ $key } = $value;
        }
        else{                   # Get the property
            $value = $self->{ $key };
        }
        return( $value );    
    }
    return undef;
}


sub fields {
my $self = shift;

    my @selfKeys = ( keys %{$self} );
    return( @selfKeys );

}

sub links {
my $self = shift;
my @links;

    foreach my $selfKey ( keys %{$self} ){
        if( $selfKey =~ m/LNK[0-9]|FLNK/ ){
            push @links, $&;
        }
    }
    return( @links );
}

sub link {
my $self = shift;
my $linkName = shift;

    if( @_ ){
        my $linkTarget = shift;
        $self->{$linkName} = $linkTarget;
        return $self->{ $linkName };    
    }
    else{
        return( $self->{ $linkName } );
    }
}

sub scan {
my $self = shift;

    if( @_ ){
        $self->{SCAN} = shift;
    }
    
    return( $self->{SCAN} );
}

sub slnks {
my $self = shift;

    if( @_ ){
        push @{ $self->{ slnks } }, shift;
    }
    return $self->{ slnks };

}

1;
