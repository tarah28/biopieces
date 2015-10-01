package Maasha::RestrictEnz;


# Copyright (C) 2006-2007 Martin A. Hansen.

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# http://www.gnu.org/copyleft/gpl.html


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> DESCRIPTION <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


# This module contains routines for matching restriction enzyme cleavage sites.


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


use warnings;
use strict;
use Data::Dumper;

use Exporter;

use vars qw( @ISA @EXPORT @EXPORT_OK );

@ISA = qw( Exporter ) ;

use Inline ( C => <<'END_C', DIRECTORY => $ENV{ "BP_TMP" } );

/*
# UIPAC ambiguity codes for nucleotides:
#
# http://droog.gs.washington.edu/parc/images/iupac.html
#
#  ACGTUMRWSYKVHDBN
# A1000011100011101
# C0100010011011011
# G0010001010110111
# T0001100101101111
# U0001100101101111
# M1100000000000000
# R1010000000000000
# W1001100000000000
# S0110000000000000
# Y0101100000000000
# K0011100000000000
# V1110000000000000
# H1101100000000000
# D1011100000000000
# B0111100000000000
# N1111100000000000
*/

/* 2-dimensional array for fast lookup of nucleotide match. */

char ambi_match[16][16] = {
    "1000011100011101",
    "0100010011011011",
    "0010001010110111",
    "0001100101101111",
    "0001100101101111",
    "1100000000000000",
    "1010000000000000",
    "1001100000000000",
    "0110000000000000",
    "0101100000000000",
    "0011100000000000",
    "1110000000000000",
    "1101100000000000",
    "1011100000000000",
    "0111100000000000",
    "1111100000000000"
};


int hash( char c )
{
    /* Martin A. Hansen, August 2009. */

    /* Given a nucletotide returns the position of this */
    /* on the edge of the symetrical ambi_match lookup table. */

    switch ( toupper( c ) )
    {
        case 'A': return 0;
        case 'C': return 1;
        case 'G': return 2;
        case 'T': return 3;
        case 'U': return 4;
        case 'M': return 5;
        case 'R': return 6;
        case 'W': return 7;
        case 'S': return 8;
        case 'Y': return 9;
        case 'K': return 10;
        case 'V': return 11;
        case 'H': return 12;
        case 'D': return 13;
        case 'B': return 14;
        case 'N': return 15;
        default: return -1;
    }
}


void scan( char *seq, char *pat, int seq_len, int pat_len )
{
    /* Martin A. Hansen, August 2009. */

    /* Scans a sequence for a subsequence allowing for ambiguity */
    /* codes ala UIPAC. */

    int i;

    Inline_Stack_Vars;
    Inline_Stack_Reset;

    for ( i = 0; i < seq_len - pat_len + 1; i++ )
    {
        if ( match( &seq[ i ], pat, pat_len ) ) {
          Inline_Stack_Push( sv_2mortal( newSViv( i ) ) );
        }
    }

    Inline_Stack_Done;
}


int match( char *seq1, char *seq2, int len )
{
    /* Martin A. Hansen, August 2009. */

    /* Checks if two sequences are identical allowing for */
    /* IUPAC amabiguity codes over a given length. */

    int  i = 0;
    char c1;
    char c2;

    while ( i < len )
    {
        c1 = seq1[ i ];
        c2 = seq2[ i ];

        if ( ambi_match[ hash( c1 ) ][ hash( c2 ) ] == '0' ) {
            return 0;
        }

        i++;
    }

    return 1;
}

END_C


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


sub re_scan
{
    # Martin A. Hansen, August 2009.

    # Calls C function to scan a given sequence for a given
    # restriction site.

    my ( $seq,   # sequence to scan
         $re,    # hashref with RE info
       ) = @_; 

    # Returns a list of integers.

    my ( @matches );

    @matches = scan( $seq, $re->{ "pattern" }, length $seq, $re->{ "len" } );

    return wantarray ? @matches: \@matches;
}


sub parse_re_data
{
    # Martin A. Hansen, August 2009.
    
    # Parses restriction enzyme data from __DATA__ section in this module.

    # Returns a list of hashrefs.

    my ( @lines, $line, @fields, @re_data );

    @lines = <DATA>;

    chomp @lines;

    foreach $line ( @lines )
    {
        next if $line =~ /^(#|$)/;

        @fields = split " ", $line;

        push @re_data, {
            name    => $fields[ 0 ],
            pattern => $fields[ 1 ],
            len     => $fields[ 2 ],
            ncuts   => $fields[ 3 ],
            blunt   => $fields[ 4 ],
            c1      => $fields[ 5 ],
            c2      => $fields[ 6 ],
            c3      => $fields[ 7 ],
            c4      => $fields[ 8 ],
        };
    }

    return wantarray ? @re_data : \@re_data;
}


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


__DATA__

# From REBASE:
# ftp://ftp.neb.com/pub/rebase/emboss_e.908

# REBASE version 908                                              emboss_e.908
#  
#     =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#     REBASE, The Restriction Enzyme Database   http://rebase.neb.com
#     Copyright (c)  Dr. Richard J. Roberts, 2009.   All rights reserved.
#     =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#  
# Rich Roberts                                                    Jul 28 2009
#  
# REBASE enzyme patterns for EMBOSS (embossre.enz)
#
# Format:
# 
# name<ws>pattern<ws>len<ws>ncuts<ws>blunt<ws>c1<ws>c2<ws>c3<ws>c4
#
# Where:
# name = name of enzyme
# pattern = recognition site
# len = length of pattern
# ncuts = number of cuts made by enzyme
#         Zero represents unknown
# blunt = true if blunt end cut, false if sticky
# c1 = First 5' cut
# c2 = First 3' cut
# c3 = Second 5' cut
# c4 = Second 3' cut
#
# Examples:
# AAC^TGG -> 6 2 1 3 3 0 0
# A^ACTGG -> 6 2 0 1 5 0 0
# AACTGG  -> 6 0 0 0 0 0 0
# AACTGG(-5/-1) -> 6 2 0 1 5 0 0
# (8/13)GACNNNNNNTCA(12/7) -> 12 4 0 -9 -14 24 19
#
# i.e. cuts are always to the right of the given
# residue and sequences are always with reference to
# the 5' strand.
# Sequences are numbered ... -3 -2 -1 1 2 3 ... with
# the first residue of the pattern at base number 1.
#
#

AanI	TTATAA	6	2	1	3	3	0	0
AarI	CACCTGC	7	2	0	11	15	0	0
AasI	GACNNNNNNGTC	12	2	0	7	5	0	0
AatI	AGGCCT	6	2	1	3	3	0	0
AatII	GACGTC	6	2	0	5	1	0	0
AbsI	CCTCGAGG	8	2	0	2	6	0	0
AccI	GTMKAC	6	2	0	2	4	0	0
AccII	CGCG	4	2	1	2	2	0	0
AccIII	TCCGGA	6	2	0	1	5	0	0
Acc16I	TGCGCA	6	2	1	3	3	0	0
Acc36I	ACCTGC	6	2	0	10	14	0	0
Acc65I	GGTACC	6	2	0	1	5	0	0
AccB1I	GGYRCC	6	2	0	1	5	0	0
AccB7I	CCANNNNNTGG	11	2	0	7	4	0	0
AccBSI	CCGCTC	6	2	1	3	3	0	0
AceIII	cagctc	6	2	0	13	17	0	0
AciI	CCGC	4	2	0	1	3	0	0
AclI	AACGTT	6	2	0	2	4	0	0
AclWI	GGATC	5	2	0	9	10	0	0
AcoI	YGGCCR	6	2	0	1	5	0	0
AcsI	RAATTY	6	2	0	1	5	0	0
AcuI	CTGAAG	6	2	0	22	20	0	0
AcvI	CACGTG	6	2	1	3	3	0	0
AcyI	GRCGYC	6	2	0	2	4	0	0
AdeI	CACNNNGTG	9	2	0	6	3	0	0
AfaI	GTAC	4	2	1	2	2	0	0
AfeI	AGCGCT	6	2	1	3	3	0	0
AfiI	CCNNNNNNNGG	11	2	0	7	4	0	0
AflII	CTTAAG	6	2	0	1	5	0	0
AflIII	ACRYGT	6	2	0	1	5	0	0
AgeI	ACCGGT	6	2	0	1	5	0	0
AgsI	TTSAA	5	2	0	3	2	0	0
AhaIII	tttaaa	6	2	1	3	3	0	0
AhdI	GACNNNNNGTC	11	2	0	6	5	0	0
AhlI	ACTAGT	6	2	0	1	5	0	0
AjiI	CACGTC	6	2	1	3	3	0	0
AjnI	CCWGG	5	2	0	-1	5	0	0
AjuI	GAANNNNNNNTTGG	14	4	0	-8	-13	25	20
AleI	CACNNNNGTG	10	2	1	5	5	0	0
AlfI	GCANNNNNNTGC	12	4	0	-11	-13	24	22
AloI	GAACNNNNNNTCC	13	4	0	-8	-13	25	20
AluI	AGCT	4	2	1	2	2	0	0
AluBI	AGCT	4	2	1	2	2	0	0
AlwI	GGATC	5	2	0	9	10	0	0
Alw21I	GWGCWC	6	2	0	5	1	0	0
Alw26I	GTCTC	5	2	0	6	10	0	0
Alw44I	GTGCAC	6	2	0	1	5	0	0
AlwFI	gaaaynnnnnrtg	13	0	0	0	0	0	0
AlwNI	CAGNNNCTG	9	2	0	6	3	0	0
Ama87I	CYCGRG	6	2	0	1	5	0	0
Aor13HI	TCCGGA	6	2	0	1	5	0	0
Aor51HI	AGCGCT	6	2	1	3	3	0	0
ApaI	GGGCCC	6	2	0	5	1	0	0
ApaBI	gcannnnntgc	11	2	0	8	3	0	0
ApaLI	GTGCAC	6	2	0	1	5	0	0
ApeKI	GCWGC	5	2	0	1	4	0	0
ApoI	RAATTY	6	2	0	1	5	0	0
ApyPI	atcgac	6	2	0	26	24	0	0
AquIII	gaggag	6	2	0	26	24	0	0
AquIV	grggaag	7	2	0	26	24	0	0
ArsI	GACNNNNNNTTYG	13	4	0	-9	-14	24	19
AscI	GGCGCGCC	8	2	0	2	6	0	0
AseI	ATTAAT	6	2	0	2	4	0	0
Asi256I	gatc	4	2	0	1	3	0	0
AsiGI	ACCGGT	6	2	0	1	5	0	0
AsiSI	GCGATCGC	8	2	0	5	3	0	0
AspI	GACNNNGTC	9	2	0	4	5	0	0
Asp700I	GAANNNNTTC	10	2	1	5	5	0	0
Asp718I	GGTACC	6	2	0	1	5	0	0
AspA2I	CCTAGG	6	2	0	1	5	0	0
AspCNI	gccgc	5	0	0	0	0	0	0
AspEI	GACNNNNNGTC	11	2	0	6	5	0	0
AspLEI	GCGC	4	2	0	3	1	0	0
AspS9I	GGNCC	5	2	0	1	4	0	0
AssI	AGTACT	6	2	1	3	3	0	0
AsuI	ggncc	5	2	0	1	4	0	0
AsuII	TTCGAA	6	2	0	2	4	0	0
AsuC2I	CCSGG	5	2	0	2	3	0	0
AsuHPI	GGTGA	5	2	0	13	12	0	0
AsuNHI	GCTAGC	6	2	0	1	5	0	0
AvaI	CYCGRG	6	2	0	1	5	0	0
AvaII	GGWCC	5	2	0	1	4	0	0
AvaIII	atgcat	6	0	0	0	0	0	0
AviII	TGCGCA	6	2	1	3	3	0	0
AvrII	CCTAGG	6	2	0	1	5	0	0
AxyI	CCTNAGG	7	2	0	2	5	0	0
BaeI	ACNNNNGTAYC	11	4	0	-11	-16	23	18
BaeGI	GKGCMC	6	2	0	5	1	0	0
BalI	TGGCCA	6	2	1	3	3	0	0
BamHI	GGATCC	6	2	0	1	5	0	0
BanI	GGYRCC	6	2	0	1	5	0	0
BanII	GRGCYC	6	2	0	5	1	0	0
BanIII	ATCGAT	6	2	0	2	4	0	0
BarI	GAAGNNNNNNTAC	13	4	0	-8	-13	25	20
BasI	CCANNNNNTGG	11	2	0	7	4	0	0
BauI	CACGAG	6	2	0	1	5	0	0
BbeI	GGCGCC	6	2	0	5	1	0	0
Bbr7I	gaagac	6	2	0	13	17	0	0
BbrPI	CACGTG	6	2	1	3	3	0	0
BbsI	GAAGAC	6	2	0	8	12	0	0
BbuI	GCATGC	6	2	0	5	1	0	0
BbvI	GCAGC	5	2	0	13	17	0	0
BbvII	gaagac	6	2	0	8	12	0	0
Bbv12I	GWGCWC	6	2	0	5	1	0	0
BbvCI	CCTCAGC	7	2	0	2	5	0	0
BccI	CCATC	5	2	0	9	10	0	0
Bce83I	cttgag	6	2	0	22	20	0	0
BceAI	ACGGC	5	2	0	17	19	0	0
BcefI	acggc	5	2	0	17	18	0	0
BcgI	CGANNNNNNTGC	12	4	0	-11	-13	24	22
BciVI	GTATCC	6	2	0	12	11	0	0
BclI	TGATCA	6	2	0	1	5	0	0
BcnI	CCSGG	5	2	0	2	3	0	0
BcuI	ACTAGT	6	2	0	1	5	0	0
BdaI	TGANNNNNNTCA	12	4	0	-11	-13	24	22
BetI	wccggw	6	2	0	1	5	0	0
BfaI	CTAG	4	2	0	1	3	0	0
BfiI	ACTGGG	6	2	0	11	10	0	0
BfmI	CTRYAG	6	2	0	1	5	0	0
BfoI	RGCGCY	6	2	0	5	1	0	0
BfrI	CTTAAG	6	2	0	1	5	0	0
BfuI	GTATCC	6	2	0	12	11	0	0
BfuAI	ACCTGC	6	2	0	10	14	0	0
BfuCI	GATC	4	2	0	-1	4	0	0
BglI	GCCNNNNNGGC	11	2	0	7	4	0	0
BglII	AGATCT	6	2	0	1	5	0	0
BinI	ggatc	5	2	0	9	10	0	0
BisI	GCNGC	5	2	0	2	3	0	0
BlnI	CCTAGG	6	2	0	1	5	0	0
BlpI	GCTNAGC	7	2	0	2	5	0	0
BlsI	GCNGC	5	2	0	3	2	0	0
BmcAI	AGTACT	6	2	1	3	3	0	0
Bme18I	GGWCC	5	2	0	1	4	0	0
Bme1390I	CCNGG	5	2	0	2	3	0	0
BmeRI	GACNNNNNGTC	11	2	0	6	5	0	0
BmeT110I	CYCGRG	6	2	0	1	5	0	0
BmgI	gkgccc	6	0	0	0	0	0	0
BmgBI	CACGTC	6	2	1	3	3	0	0
BmgT120I	GGNCC	5	2	0	2	3	0	0
BmiI	GGNNCC	6	2	1	3	3	0	0
BmrI	ACTGGG	6	2	0	11	10	0	0
BmrFI	CCNGG	5	2	0	2	3	0	0
BmsI	GCATC	5	2	0	10	14	0	0
BmtI	GCTAGC	6	2	0	5	1	0	0
BmuI	ACTGGG	6	2	0	11	10	0	0
BoxI	GACNNNNGTC	10	2	1	5	5	0	0
BpiI	GAAGAC	6	2	0	8	12	0	0
BplI	GAGNNNNNCTC	11	4	0	-9	-14	24	19
BpmI	CTGGAG	6	2	0	22	20	0	0
Bpu10I	CCTNAGC	7	2	0	2	5	0	0
Bpu14I	TTCGAA	6	2	0	2	4	0	0
Bpu1102I	GCTNAGC	7	2	0	2	5	0	0
BpuAI	GAAGAC	6	2	0	8	12	0	0
BpuEI	CTTGAG	6	2	0	22	20	0	0
BpuMI	CCSGG	5	2	0	2	3	0	0
BpvUI	CGATCG	6	2	0	4	2	0	0
BsaI	GGTCTC	6	2	0	7	11	0	0
Bsa29I	ATCGAT	6	2	0	2	4	0	0
BsaAI	YACGTR	6	2	1	3	3	0	0
BsaBI	GATNNNNATC	10	2	1	5	5	0	0
BsaHI	GRCGYC	6	2	0	2	4	0	0
BsaJI	CCNNGG	6	2	0	1	5	0	0
BsaMI	GAATGC	6	2	0	7	5	0	0
BsaWI	WCCGGW	6	2	0	1	5	0	0
BsaXI	ACNNNNNCTCC	11	4	0	-10	-13	21	18
BsbI	caacac	6	2	0	27	25	0	0
Bsc4I	CCNNNNNNNGG	11	2	0	7	4	0	0
BscAI	gcatc	5	2	0	9	11	0	0
BscGI	cccgt	5	0	0	0	0	0	0
Bse1I	ACTGG	5	2	0	6	4	0	0
Bse8I	GATNNNNATC	10	2	1	5	5	0	0
Bse21I	CCTNAGG	7	2	0	2	5	0	0
Bse118I	RCCGGY	6	2	0	1	5	0	0
BseAI	TCCGGA	6	2	0	1	5	0	0
BseBI	CCWGG	5	2	0	2	3	0	0
BseCI	ATCGAT	6	2	0	2	4	0	0
BseDI	CCNNGG	6	2	0	1	5	0	0
Bse3DI	GCAATG	6	2	0	8	6	0	0
BseGI	GGATG	5	2	0	7	5	0	0
BseJI	GATNNNNATC	10	2	1	5	5	0	0
BseLI	CCNNNNNNNGG	11	2	0	7	4	0	0
BseMI	GCAATG	6	2	0	8	6	0	0
BseMII	CTCAG	5	2	0	15	13	0	0
BseNI	ACTGG	5	2	0	6	4	0	0
BsePI	GCGCGC	6	2	0	1	5	0	0
BseRI	GAGGAG	6	2	0	16	14	0	0
BseSI	GKGCMC	6	2	0	5	1	0	0
BseXI	GCAGC	5	2	0	13	17	0	0
BseX3I	CGGCCG	6	2	0	1	5	0	0
BseYI	CCCAGC	6	2	0	1	5	0	0
BsgI	GTGCAG	6	2	0	22	20	0	0
Bsh1236I	CGCG	4	2	1	2	2	0	0
Bsh1285I	CGRYCG	6	2	0	4	2	0	0
BshFI	GGCC	4	2	1	2	2	0	0
BshNI	GGYRCC	6	2	0	1	5	0	0
BshTI	ACCGGT	6	2	0	1	5	0	0
BshVI	ATCGAT	6	2	0	2	4	0	0
BsiI	cacgag	6	2	0	1	5	0	0
BsiEI	CGRYCG	6	2	0	4	2	0	0
BsiHKAI	GWGCWC	6	2	0	5	1	0	0
BsiHKCI	CYCGRG	6	2	0	1	5	0	0
BsiSI	CCGG	4	2	0	1	3	0	0
BsiWI	CGTACG	6	2	0	1	5	0	0
BsiYI	ccnnnnnnngg	11	2	0	7	4	0	0
BslI	CCNNNNNNNGG	11	2	0	7	4	0	0
BslFI	GGGAC	5	2	0	15	19	0	0
BsmI	GAATGC	6	2	0	7	5	0	0
BsmAI	GTCTC	5	2	0	6	10	0	0
BsmBI	CGTCTC	6	2	0	7	11	0	0
BsmFI	GGGAC	5	2	0	15	19	0	0
BsnI	GGCC	4	2	1	2	2	0	0
Bso31I	GGTCTC	6	2	0	7	11	0	0
BsoBI	CYCGRG	6	2	0	1	5	0	0
Bsp13I	TCCGGA	6	2	0	1	5	0	0
Bsp19I	CCATGG	6	2	0	1	5	0	0
Bsp24I	gacnnnnnntgg	12	4	0	-9	-14	24	19
Bsp68I	TCGCGA	6	2	1	3	3	0	0
Bsp119I	TTCGAA	6	2	0	2	4	0	0
Bsp120I	GGGCCC	6	2	0	1	5	0	0
Bsp143I	GATC	4	2	0	-1	4	0	0
Bsp1286I	GDGCHC	6	2	0	5	1	0	0
Bsp1407I	TGTACA	6	2	0	1	5	0	0
Bsp1720I	GCTNAGC	7	2	0	2	5	0	0
BspACI	CCGC	4	2	0	1	3	0	0
BspCNI	CTCAG	5	2	0	14	12	0	0
BspDI	ATCGAT	6	2	0	2	4	0	0
BspD6I	gactc	5	2	0	9	11	0	0
BspEI	TCCGGA	6	2	0	1	5	0	0
BspFNI	CGCG	4	2	1	2	2	0	0
BspGI	ctggac	6	0	0	0	0	0	0
BspHI	TCATGA	6	2	0	1	5	0	0
BspLI	GGNNCC	6	2	1	3	3	0	0
BspLU11I	acatgt	6	2	0	1	5	0	0
BspMI	ACCTGC	6	2	0	10	14	0	0
BspMII	tccgga	6	2	0	1	5	0	0
BspNCI	ccaga	5	0	0	0	0	0	0
BspOI	GCTAGC	6	2	0	5	1	0	0
BspPI	GGATC	5	2	0	9	10	0	0
BspQI	GCTCTTC	7	2	0	8	11	0	0
BspTI	CTTAAG	6	2	0	1	5	0	0
BspT104I	TTCGAA	6	2	0	2	4	0	0
BspT107I	GGYRCC	6	2	0	1	5	0	0
BspTNI	GGTCTC	6	2	0	7	11	0	0
BspXI	ATCGAT	6	2	0	2	4	0	0
BsrI	ACTGG	5	2	0	6	4	0	0
BsrBI	CCGCTC	6	2	1	3	3	0	0
BsrDI	GCAATG	6	2	0	8	6	0	0
BsrFI	RCCGGY	6	2	0	1	5	0	0
BsrGI	TGTACA	6	2	0	1	5	0	0
BsrSI	ACTGG	5	2	0	6	4	0	0
BssAI	RCCGGY	6	2	0	1	5	0	0
BssECI	CCNNGG	6	2	0	1	5	0	0
BssHII	GCGCGC	6	2	0	1	5	0	0
BssKI	CCNGG	5	2	0	-1	5	0	0
BssMI	GATC	4	2	0	-1	4	0	0
BssNI	GRCGYC	6	2	0	2	4	0	0
BssNAI	GTATAC	6	2	1	3	3	0	0
BssSI	CACGAG	6	2	0	1	5	0	0
BssT1I	CCWWGG	6	2	0	1	5	0	0
Bst6I	CTCTTC	6	2	0	7	10	0	0
Bst98I	CTTAAG	6	2	0	1	5	0	0
Bst1107I	GTATAC	6	2	1	3	3	0	0
BstACI	GRCGYC	6	2	0	2	4	0	0
BstAFI	CTTAAG	6	2	0	1	5	0	0
BstAPI	GCANNNNNTGC	11	2	0	7	4	0	0
BstAUI	TGTACA	6	2	0	1	5	0	0
BstBI	TTCGAA	6	2	0	2	4	0	0
Bst2BI	CACGAG	6	2	0	1	5	0	0
BstBAI	YACGTR	6	2	1	3	3	0	0
Bst4CI	ACNGT	5	2	0	3	2	0	0
BstC8I	GCNNGC	6	2	1	3	3	0	0
BstDEI	CTNAG	5	2	0	1	4	0	0
BstDSI	CCRYGG	6	2	0	1	5	0	0
BstEII	GGTNACC	7	2	0	1	6	0	0
BstENI	CCTNNNNNAGG	11	2	0	5	6	0	0
BstF5I	GGATG	5	2	0	7	5	0	0
BstFNI	CGCG	4	2	1	2	2	0	0
BstH2I	RGCGCY	6	2	0	5	1	0	0
BstHHI	GCGC	4	2	0	3	1	0	0
BstKTI	GATC	4	2	0	3	1	0	0
BstMAI	GTCTC	5	2	0	6	10	0	0
BstMBI	GATC	4	2	0	-1	4	0	0
BstMCI	CGRYCG	6	2	0	4	2	0	0
BstMWI	GCNNNNNNNGC	11	2	0	7	4	0	0
BstNI	CCWGG	5	2	0	2	3	0	0
BstNSI	RCATGY	6	2	0	5	1	0	0
BstOI	CCWGG	5	2	0	2	3	0	0
BstPI	GGTNACC	7	2	0	1	6	0	0
BstPAI	GACNNNNGTC	10	2	1	5	5	0	0
BstSCI	CCNGG	5	2	0	-1	5	0	0
BstSFI	CTRYAG	6	2	0	1	5	0	0
BstSLI	GKGCMC	6	2	0	5	1	0	0
BstSNI	TACGTA	6	2	1	3	3	0	0
BstUI	CGCG	4	2	1	2	2	0	0
Bst2UI	CCWGG	5	2	0	2	3	0	0
BstV1I	GCAGC	5	2	0	13	17	0	0
BstV2I	GAAGAC	6	2	0	8	12	0	0
BstXI	CCANNNNNNTGG	12	2	0	8	4	0	0
BstX2I	RGATCY	6	2	0	1	5	0	0
BstYI	RGATCY	6	2	0	1	5	0	0
BstZI	CGGCCG	6	2	0	1	5	0	0
BstZ17I	GTATAC	6	2	1	3	3	0	0
Bsu15I	ATCGAT	6	2	0	2	4	0	0
Bsu36I	CCTNAGG	7	2	0	2	5	0	0
BsuRI	GGCC	4	2	1	2	2	0	0
BsuTUI	ATCGAT	6	2	0	2	4	0	0
BtgI	CCRYGG	6	2	0	1	5	0	0
BtgZI	GCGATG	6	2	0	16	20	0	0
BthCI	gcngc	5	2	0	4	1	0	0
BtrI	CACGTC	6	2	1	3	3	0	0
BtsI	GCAGTG	6	2	0	8	6	0	0
BtsCI	GGATG	5	2	0	7	5	0	0
BtuMI	TCGCGA	6	2	1	3	3	0	0
BveI	ACCTGC	6	2	0	10	14	0	0
Cac8I	GCNNGC	6	2	1	3	3	0	0
CaiI	CAGNNNCTG	9	2	0	6	3	0	0
CauII	ccsgg	5	2	0	2	3	0	0
CciI	TCATGA	6	2	0	1	5	0	0
CciNI	GCGGCCGC	8	2	0	2	6	0	0
CdiI	catcg	5	2	1	4	4	0	0
CdpI	gcggag	6	2	0	26	24	0	0
CelII	GCTNAGC	7	2	0	2	5	0	0
CfoI	GCGC	4	2	0	3	1	0	0
CfrI	YGGCCR	6	2	0	1	5	0	0
Cfr9I	CCCGGG	6	2	0	1	5	0	0
Cfr10I	RCCGGY	6	2	0	1	5	0	0
Cfr13I	GGNCC	5	2	0	1	4	0	0
Cfr42I	CCGCGG	6	2	0	4	2	0	0
ChaI	gatc	4	2	0	4	-1	0	0
CjeI	ccannnnnngt	11	4	0	-9	-15	26	20
CjeNII	gagnnnnngt	10	0	0	0	0	0	0
CjePI	ccannnnnnntc	12	4	0	-8	-14	26	20
CjuI	caynnnnnrtg	11	0	0	0	0	0	0
CjuII	caynnnnnctc	11	0	0	0	0	0	0
ClaI	ATCGAT	6	2	0	2	4	0	0
CpoI	CGGWCCG	7	2	0	2	5	0	0
CseI	GACGC	5	2	0	10	15	0	0
CsiI	ACCWGGT	7	2	0	1	6	0	0
CspI	CGGWCCG	7	2	0	2	5	0	0
Csp6I	GTAC	4	2	0	1	3	0	0
Csp45I	TTCGAA	6	2	0	2	4	0	0
CspAI	ACCGGT	6	2	0	1	5	0	0
CspCI	CAANNNNNGTGG	12	4	0	-12	-14	24	22
CstMI	aaggag	6	2	0	26	24	0	0
CviAII	CATG	4	2	0	1	3	0	0
CviJI	RGCY	4	2	1	2	2	0	0
CviKI-1	RGCY	4	2	1	2	2	0	0
CviQI	GTAC	4	2	0	1	3	0	0
CviRI	tgca	4	2	1	2	2	0	0
DdeI	CTNAG	5	2	0	1	4	0	0
DinI	GGCGCC	6	2	1	3	3	0	0
DpnI	GATC	4	2	1	2	2	0	0
DpnII	GATC	4	2	0	-1	4	0	0
DraI	TTTAAA	6	2	1	3	3	0	0
DraII	RGGNCCY	7	2	0	2	5	0	0
DraIII	CACNNNGTG	9	2	0	6	3	0	0
DraRI	caagnac	7	2	0	27	25	0	0
DrdI	GACNNNNNNGTC	12	2	0	7	5	0	0
DrdII	gaacca	6	0	0	0	0	0	0
DrdIV	tacgac	6	2	0	26	24	0	0
DriI	GACNNNNNGTC	11	2	0	6	5	0	0
DsaI	ccrygg	6	2	0	1	5	0	0
DseDI	GACNNNNNNGTC	12	2	0	7	5	0	0
EaeI	YGGCCR	6	2	0	1	5	0	0
EagI	CGGCCG	6	2	0	1	5	0	0
Eam1104I	CTCTTC	6	2	0	7	10	0	0
Eam1105I	GACNNNNNGTC	11	2	0	6	5	0	0
EarI	CTCTTC	6	2	0	7	10	0	0
EciI	GGCGGA	6	2	0	17	15	0	0
Ecl136II	GAGCTC	6	2	1	3	3	0	0
EclXI	CGGCCG	6	2	0	1	5	0	0
Eco24I	GRGCYC	6	2	0	5	1	0	0
Eco31I	GGTCTC	6	2	0	7	11	0	0
Eco32I	GATATC	6	2	1	3	3	0	0
Eco47I	GGWCC	5	2	0	1	4	0	0
Eco47III	AGCGCT	6	2	1	3	3	0	0
Eco52I	CGGCCG	6	2	0	1	5	0	0
Eco57I	CTGAAG	6	2	0	22	20	0	0
Eco72I	CACGTG	6	2	1	3	3	0	0
Eco81I	CCTNAGG	7	2	0	2	5	0	0
Eco88I	CYCGRG	6	2	0	1	5	0	0
Eco91I	GGTNACC	7	2	0	1	6	0	0
Eco105I	TACGTA	6	2	1	3	3	0	0
Eco130I	CCWWGG	6	2	0	1	5	0	0
Eco147I	AGGCCT	6	2	1	3	3	0	0
EcoHI	ccsgg	5	2	0	-1	5	0	0
EcoICRI	GAGCTC	6	2	1	3	3	0	0
Eco57MI	CTGRAG	6	2	0	22	20	0	0
EcoNI	CCTNNNNNAGG	11	2	0	5	6	0	0
EcoO65I	GGTNACC	7	2	0	1	6	0	0
EcoO109I	RGGNCCY	7	2	0	2	5	0	0
EcoRI	GAATTC	6	2	0	1	5	0	0
EcoRII	CCWGG	5	2	0	-1	5	0	0
EcoRV	GATATC	6	2	1	3	3	0	0
EcoT14I	CCWWGG	6	2	0	1	5	0	0
EcoT22I	ATGCAT	6	2	0	5	1	0	0
EcoT38I	GRGCYC	6	2	0	5	1	0	0
Eco53kI	GAGCTC	6	2	1	3	3	0	0
EgeI	GGCGCC	6	2	1	3	3	0	0
EheI	GGCGCC	6	2	1	3	3	0	0
ErhI	CCWWGG	6	2	0	1	5	0	0
EsaBC3I	tcga	4	2	1	2	2	0	0
EsaSSI	gaccac	6	0	0	0	0	0	0
EspI	gctnagc	7	2	0	2	5	0	0
Esp3I	CGTCTC	6	2	0	7	11	0	0
FaeI	CATG	4	2	0	4	-1	0	0
FaiI	YATR	4	2	1	2	2	0	0
FalI	AAGNNNNNCTT	11	4	0	-9	-14	24	19
FaqI	GGGAC	5	2	0	15	19	0	0
FatI	CATG	4	2	0	-1	4	0	0
FauI	CCCGC	5	2	0	9	11	0	0
FauNDI	CATATG	6	2	0	2	4	0	0
FbaI	TGATCA	6	2	0	1	5	0	0
FblI	GTMKAC	6	2	0	2	4	0	0
FinI	gggac	5	0	0	0	0	0	0
FmuI	ggncc	5	2	0	4	1	0	0
FnuDII	cgcg	4	2	1	2	2	0	0
Fnu4HI	GCNGC	5	2	0	2	3	0	0
FokI	GGATG	5	2	0	14	18	0	0
FriOI	GRGCYC	6	2	0	5	1	0	0
FseI	GGCCGGCC	8	2	0	6	2	0	0
FspI	TGCGCA	6	2	1	3	3	0	0
FspAI	RTGCGCAY	8	2	1	4	4	0	0
FspBI	CTAG	4	2	0	1	3	0	0
Fsp4HI	GCNGC	5	2	0	2	3	0	0
GdiII	cggccr	6	2	0	1	5	0	0
GlaI	GCGC	4	2	1	2	2	0	0
GluI	GCNGC	5	2	0	2	3	0	0
GsaI	CCCAGC	6	2	0	5	1	0	0
GsuI	CTGGAG	6	2	0	22	20	0	0
HaeI	wggccw	6	2	1	3	3	0	0
HaeII	RGCGCY	6	2	0	5	1	0	0
HaeIII	GGCC	4	2	1	2	2	0	0
HaeIV	gaynnnnnrtc	11	4	0	-8	-14	25	20
HapII	CCGG	4	2	0	1	3	0	0
HgaI	GACGC	5	2	0	10	15	0	0
HgiAI	gwgcwc	6	2	0	5	1	0	0
HgiCI	ggyrcc	6	2	0	1	5	0	0
HgiEII	accnnnnnnggt	12	0	0	0	0	0	0
HgiJII	grgcyc	6	2	0	5	1	0	0
HhaI	GCGC	4	2	0	3	1	0	0
Hin1I	GRCGYC	6	2	0	2	4	0	0
Hin1II	CATG	4	2	0	4	-1	0	0
Hin4I	GAYNNNNNVTC	11	4	0	-9	-14	24	19
Hin4II	ccttc	5	2	0	11	10	0	0
Hin6I	GCGC	4	2	0	1	3	0	0
HinP1I	GCGC	4	2	0	1	3	0	0
HincII	GTYRAC	6	2	1	3	3	0	0
HindII	GTYRAC	6	2	1	3	3	0	0
HindIII	AAGCTT	6	2	0	1	5	0	0
HinfI	GANTC	5	2	0	1	4	0	0
HpaI	GTTAAC	6	2	1	3	3	0	0
HpaII	CCGG	4	2	0	1	3	0	0
HphI	GGTGA	5	2	0	13	12	0	0
Hpy8I	GTNNAC	6	2	1	3	3	0	0
Hpy99I	CGWCG	5	2	0	5	-1	0	0
Hpy166II	GTNNAC	6	2	1	3	3	0	0
Hpy178III	tcnnga	6	2	0	2	4	0	0
Hpy188I	TCNGA	5	2	0	3	2	0	0
Hpy188III	TCNNGA	6	2	0	2	4	0	0
HpyAV	CCTTC	5	2	0	11	10	0	0
HpyCH4III	ACNGT	5	2	0	3	2	0	0
HpyCH4IV	ACGT	4	2	0	1	3	0	0
HpyCH4V	TGCA	4	2	1	2	2	0	0
HpyF3I	CTNAG	5	2	0	1	4	0	0
HpyF10VI	GCNNNNNNNGC	11	2	0	7	4	0	0
Hsp92I	GRCGYC	6	2	0	2	4	0	0
Hsp92II	CATG	4	2	0	4	-1	0	0
HspAI	GCGC	4	2	0	1	3	0	0
ItaI	GCNGC	5	2	0	2	3	0	0
KasI	GGCGCC	6	2	0	1	5	0	0
KflI	GGGWCCC	7	2	0	2	5	0	0
KpnI	GGTACC	6	2	0	5	1	0	0
Kpn2I	TCCGGA	6	2	0	1	5	0	0
KspI	CCGCGG	6	2	0	4	2	0	0
Ksp22I	TGATCA	6	2	0	1	5	0	0
Ksp632I	ctcttc	6	2	0	7	10	0	0
KspAI	GTTAAC	6	2	1	3	3	0	0
Kzo9I	GATC	4	2	0	-1	4	0	0
LguI	GCTCTTC	7	2	0	8	11	0	0
LpnI	rgcgcy	6	2	1	3	3	0	0
Lsp1109I	GCAGC	5	2	0	13	17	0	0
LweI	GCATC	5	2	0	10	14	0	0
MabI	ACCWGGT	7	2	0	1	6	0	0
MaeI	CTAG	4	2	0	1	3	0	0
MaeII	ACGT	4	2	0	1	3	0	0
MaeIII	GTNAC	5	2	0	-1	5	0	0
MalI	GATC	4	2	1	2	2	0	0
MaqI	crttgac	7	2	0	28	26	0	0
MauBI	CGCGCGCG	8	2	0	2	6	0	0
MbiI	CCGCTC	6	2	1	3	3	0	0
MboI	GATC	4	2	0	-1	4	0	0
MboII	GAAGA	5	2	0	13	12	0	0
McaTI	gcgcgc	6	2	0	4	2	0	0
McrI	cgrycg	6	2	0	4	2	0	0
MfeI	CAATTG	6	2	0	1	5	0	0
MflI	RGATCY	6	2	0	1	5	0	0
MhlI	GDGCHC	6	2	0	5	1	0	0
MjaIV	gtnnac	6	0	0	0	0	0	0
MlsI	TGGCCA	6	2	1	3	3	0	0
MluI	ACGCGT	6	2	0	1	5	0	0
MluNI	TGGCCA	6	2	1	3	3	0	0
MlyI	GAGTC	5	2	1	10	10	0	0
Mly113I	GGCGCC	6	2	0	2	4	0	0
MmeI	TCCRAC	6	2	0	26	24	0	0
MnlI	CCTC	4	2	0	11	10	0	0
Mph1103I	ATGCAT	6	2	0	5	1	0	0
MreI	CGCCGGCG	8	2	0	2	6	0	0
MroI	TCCGGA	6	2	0	1	5	0	0
MroNI	GCCGGC	6	2	0	1	5	0	0
MroXI	GAANNNNTTC	10	2	1	5	5	0	0
MscI	TGGCCA	6	2	1	3	3	0	0
MseI	TTAA	4	2	0	1	3	0	0
MslI	CAYNNNNRTG	10	2	1	5	5	0	0
MspI	CCGG	4	2	0	1	3	0	0
Msp20I	TGGCCA	6	2	1	3	3	0	0
MspA1I	CMGCKG	6	2	1	3	3	0	0
MspCI	CTTAAG	6	2	0	1	5	0	0
MspR9I	CCNGG	5	2	0	2	3	0	0
MssI	GTTTAAAC	8	2	1	4	4	0	0
MstI	tgcgca	6	2	1	3	3	0	0
MunI	CAATTG	6	2	0	1	5	0	0
MvaI	CCWGG	5	2	0	2	3	0	0
Mva1269I	GAATGC	6	2	0	7	5	0	0
MvnI	CGCG	4	2	1	2	2	0	0
MvrI	CGATCG	6	2	0	4	2	0	0
MwoI	GCNNNNNNNGC	11	2	0	7	4	0	0
NaeI	GCCGGC	6	2	1	3	3	0	0
NarI	GGCGCC	6	2	0	2	4	0	0
NciI	CCSGG	5	2	0	2	3	0	0
NcoI	CCATGG	6	2	0	1	5	0	0
NdeI	CATATG	6	2	0	2	4	0	0
NdeII	GATC	4	2	0	-1	4	0	0
NgoAVIII	gacnnnnntga	11	4	0	-13	-15	24	22
NgoMIV	GCCGGC	6	2	0	1	5	0	0
NhaXI	caagrag	7	0	0	0	0	0	0
NheI	GCTAGC	6	2	0	1	5	0	0
NlaIII	CATG	4	2	0	4	-1	0	0
NlaIV	GGNNCC	6	2	1	3	3	0	0
NlaCI	catcac	6	2	0	25	23	0	0
Nli3877I	cycgrg	6	2	0	5	1	0	0
NmeAIII	GCCGAG	6	2	0	27	25	0	0
NmeDI	rccggy	6	4	0	-13	-8	13	18
NmuCI	GTSAC	5	2	0	-1	5	0	0
NotI	GCGGCCGC	8	2	0	2	6	0	0
NruI	TCGCGA	6	2	1	3	3	0	0
NsbI	TGCGCA	6	2	1	3	3	0	0
NsiI	ATGCAT	6	2	0	5	1	0	0
NspI	RCATGY	6	2	0	5	1	0	0
NspV	TTCGAA	6	2	0	2	4	0	0
NspBII	cmgckg	6	2	1	3	3	0	0
OliI	CACNNNNGTG	10	2	1	5	5	0	0
PabI	gtac	4	2	0	3	1	0	0
PacI	TTAATTAA	8	2	0	5	3	0	0
PaeI	GCATGC	6	2	0	5	1	0	0
PaeR7I	CTCGAG	6	2	0	1	5	0	0
PagI	TCATGA	6	2	0	1	5	0	0
PalAI	GGCGCGCC	8	2	0	2	6	0	0
PasI	CCCWGGG	7	2	0	2	5	0	0
PauI	GCGCGC	6	2	0	1	5	0	0
PceI	AGGCCT	6	2	1	3	3	0	0
PciI	ACATGT	6	2	0	1	5	0	0
PciSI	GCTCTTC	7	2	0	8	11	0	0
PctI	GAATGC	6	2	0	7	5	0	0
PdiI	GCCGGC	6	2	1	3	3	0	0
PdmI	GAANNNNTTC	10	2	1	5	5	0	0
PfeI	GAWTC	5	2	0	1	4	0	0
Pfl23II	CGTACG	6	2	0	1	5	0	0
Pfl1108I	tcgtag	6	0	0	0	0	0	0
PflFI	GACNNNGTC	9	2	0	4	5	0	0
PflMI	CCANNNNNTGG	11	2	0	7	4	0	0
PfoI	TCCNGGA	7	2	0	1	6	0	0
PhoI	GGCC	4	2	1	2	2	0	0
PinAI	ACCGGT	6	2	0	1	5	0	0
PlaDI	catcag	6	2	0	27	25	0	0
PleI	GAGTC	5	2	0	9	10	0	0
Ple19I	CGATCG	6	2	0	4	2	0	0
PmaCI	CACGTG	6	2	1	3	3	0	0
PmeI	GTTTAAAC	8	2	1	4	4	0	0
PmlI	CACGTG	6	2	1	3	3	0	0
PpiI	GAACNNNNNCTC	12	4	0	-8	-13	25	20
PpsI	GAGTC	5	2	0	9	10	0	0
Ppu10I	atgcat	6	2	0	1	5	0	0
Ppu21I	YACGTR	6	2	1	3	3	0	0
PpuMI	RGGWCCY	7	2	0	2	5	0	0
PscI	ACATGT	6	2	0	1	5	0	0
PshAI	GACNNNNGTC	10	2	1	5	5	0	0
PshBI	ATTAAT	6	2	0	2	4	0	0
PsiI	TTATAA	6	2	1	3	3	0	0
Psp03I	ggwcc	5	2	0	4	1	0	0
Psp5II	RGGWCCY	7	2	0	2	5	0	0
Psp6I	CCWGG	5	2	0	-1	5	0	0
Psp1406I	AACGTT	6	2	0	2	4	0	0
Psp124BI	GAGCTC	6	2	0	5	1	0	0
PspCI	CACGTG	6	2	1	3	3	0	0
PspEI	GGTNACC	7	2	0	1	6	0	0
PspGI	CCWGG	5	2	0	-1	5	0	0
PspLI	CGTACG	6	2	0	1	5	0	0
PspN4I	GGNNCC	6	2	1	3	3	0	0
PspOMI	GGGCCC	6	2	0	1	5	0	0
PspOMII	cgcccar	7	2	0	27	25	0	0
PspPI	GGNCC	5	2	0	1	4	0	0
PspPPI	RGGWCCY	7	2	0	2	5	0	0
PspPRI	ccycag	6	2	0	21	19	0	0
PspXI	VCTCGAGB	8	2	0	2	6	0	0
PsrI	GAACNNNNNNTAC	13	4	0	-8	-13	25	20
PssI	rggnccy	7	2	0	5	2	0	0
PstI	CTGCAG	6	2	0	5	1	0	0
PsuI	RGATCY	6	2	0	1	5	0	0
PsyI	GACNNNGTC	9	2	0	4	5	0	0
PteI	GCGCGC	6	2	0	1	5	0	0
PvuI	CGATCG	6	2	0	4	2	0	0
PvuII	CAGCTG	6	2	1	3	3	0	0
RcaI	TCATGA	6	2	0	1	5	0	0
RceI	catcgac	7	2	0	27	25	0	0
RgaI	GCGATCGC	8	2	0	5	3	0	0
RigI	GGCCGGCC	8	2	0	6	2	0	0
RleAI	cccaca	6	2	0	18	15	0	0
RpaB5I	cgrggac	7	2	0	27	25	0	0
RruI	TCGCGA	6	2	1	3	3	0	0
RsaI	GTAC	4	2	1	2	2	0	0
RsaNI	GTAC	4	2	0	1	3	0	0
RseI	CAYNNNNRTG	10	2	1	5	5	0	0
RsrII	CGGWCCG	7	2	0	2	5	0	0
Rsr2I	CGGWCCG	7	2	0	2	5	0	0
SacI	GAGCTC	6	2	0	5	1	0	0
SacII	CCGCGG	6	2	0	4	2	0	0
SalI	GTCGAC	6	2	0	1	5	0	0
SanDI	GGGWCCC	7	2	0	2	5	0	0
SapI	GCTCTTC	7	2	0	8	11	0	0
SaqAI	TTAA	4	2	0	1	3	0	0
SatI	GCNGC	5	2	0	2	3	0	0
SauI	cctnagg	7	2	0	2	5	0	0
Sau96I	GGNCC	5	2	0	1	4	0	0
Sau3AI	GATC	4	2	0	-1	4	0	0
SbfI	CCTGCAGG	8	2	0	6	2	0	0
ScaI	AGTACT	6	2	1	3	3	0	0
SchI	GAGTC	5	2	1	10	10	0	0
SciI	ctcgag	6	2	1	3	3	0	0
ScrFI	CCNGG	5	2	0	2	3	0	0
SdaI	CCTGCAGG	8	2	0	6	2	0	0
SdeAI	cagrag	6	2	0	27	25	0	0
SdeOSI	gacnnnnrtga	11	4	0	-12	-14	23	21
SduI	GDGCHC	6	2	0	5	1	0	0
SecI	ccnngg	6	2	0	1	5	0	0
SelI	cgcg	4	2	0	-1	4	0	0
SetI	ASST	4	2	0	4	-1	0	0
SexAI	ACCWGGT	7	2	0	1	6	0	0
SfaAI	GCGATCGC	8	2	0	5	3	0	0
SfaNI	GCATC	5	2	0	10	14	0	0
SfcI	CTRYAG	6	2	0	1	5	0	0
SfeI	ctryag	6	2	0	1	5	0	0
SfiI	GGCCNNNNNGGCC	13	2	0	8	5	0	0
SfoI	GGCGCC	6	2	1	3	3	0	0
Sfr274I	CTCGAG	6	2	0	1	5	0	0
Sfr303I	CCGCGG	6	2	0	4	2	0	0
SfuI	TTCGAA	6	2	0	2	4	0	0
SgfI	GCGATCGC	8	2	0	5	3	0	0
SgrAI	CRCCGGYG	8	2	0	2	6	0	0
SgrBI	CCGCGG	6	2	0	4	2	0	0
SgrDI	CGTCGACG	8	2	0	2	6	0	0
SgsI	GGCGCGCC	8	2	0	2	6	0	0
SimI	gggtc	5	2	0	2	5	0	0
SinI	GGWCC	5	2	0	1	4	0	0
SlaI	CTCGAG	6	2	0	1	5	0	0
SmaI	CCCGGG	6	2	1	3	3	0	0
SmiI	ATTTAAAT	8	2	1	4	4	0	0
SmiMI	CAYNNNNRTG	10	2	1	5	5	0	0
SmlI	CTYRAG	6	2	0	1	5	0	0
SmoI	CTYRAG	6	2	0	1	5	0	0
SmuI	CCCGC	5	2	0	9	11	0	0
SnaI	gtatac	6	0	0	0	0	0	0
SnaBI	TACGTA	6	2	1	3	3	0	0
SpeI	ACTAGT	6	2	0	1	5	0	0
SphI	GCATGC	6	2	0	5	1	0	0
SplI	cgtacg	6	2	0	1	5	0	0
SpoDI	gcggrag	7	0	0	0	0	0	0
SrfI	GCCCGGGC	8	2	1	4	4	0	0
Sse9I	AATT	4	2	0	-1	4	0	0
Sse232I	cgccggcg	8	2	0	2	6	0	0
Sse8387I	CCTGCAGG	8	2	0	6	2	0	0
Sse8647I	aggwcct	7	2	0	2	5	0	0
SseBI	AGGCCT	6	2	1	3	3	0	0
SsiI	CCGC	4	2	0	1	3	0	0
SspI	AATATT	6	2	1	3	3	0	0
SspDI	GGCGCC	6	2	0	1	5	0	0
SspD5I	ggtga	5	2	1	13	13	0	0
SstI	GAGCTC	6	2	0	5	1	0	0
SstII	CCGCGG	6	2	0	4	2	0	0
Sth132I	cccg	4	2	0	8	12	0	0
Sth302II	ccgg	4	2	1	2	2	0	0
StrI	CTCGAG	6	2	0	1	5	0	0
StsI	ggatg	5	2	0	15	19	0	0
StuI	AGGCCT	6	2	1	3	3	0	0
StyI	CCWWGG	6	2	0	1	5	0	0
StyD4I	CCNGG	5	2	0	-1	5	0	0
SwaI	ATTTAAAT	8	2	1	4	4	0	0
TaaI	ACNGT	5	2	0	3	2	0	0
TaiI	ACGT	4	2	0	4	-1	0	0
TaqI	TCGA	4	2	0	1	3	0	0
TaqII	GACCGA	6	2	0	17	15	0	0
TaqII	CACCCA	6	2	0	17	15	0	0
TasI	AATT	4	2	0	-1	4	0	0
TatI	WGTACW	6	2	0	1	5	0	0
TauI	GCSGC	5	2	0	4	1	0	0
TfiI	GAWTC	5	2	0	1	4	0	0
TliI	CTCGAG	6	2	0	1	5	0	0
Tru1I	TTAA	4	2	0	1	3	0	0
Tru9I	TTAA	4	2	0	1	3	0	0
TscAI	CASTG	5	2	0	7	-3	0	0
TseI	GCWGC	5	2	0	1	4	0	0
TsoI	TARCCA	6	2	0	17	15	0	0
Tsp45I	GTSAC	5	2	0	-1	5	0	0
Tsp509I	AATT	4	2	0	-1	4	0	0
Tsp4CI	acngt	5	2	0	3	2	0	0
TspDTI	ATGAA	5	2	0	16	14	0	0
TspEI	AATT	4	2	0	-1	4	0	0
TspGWI	ACGGA	5	2	0	16	14	0	0
TspMI	CCCGGG	6	2	0	1	5	0	0
TspRI	CASTG	5	2	0	7	-3	0	0
TssI	gagnnnctc	9	0	0	0	0	0	0
TstI	CACNNNNNNTCC	12	4	0	-9	-14	24	19
TsuI	gcgac	5	0	0	0	0	0	0
Tth111I	GACNNNGTC	9	2	0	4	5	0	0
Tth111II	caarca	6	2	0	17	15	0	0
UbaF9I	tacnnnnnrtgt	12	0	0	0	0	0	0
UbaF11I	tcgta	5	0	0	0	0	0	0
UbaF12I	ctacnnngtc	10	0	0	0	0	0	0
UbaF13I	gagnnnnnnctgg	13	0	0	0	0	0	0
UbaF14I	ccannnnntcg	11	0	0	0	0	0	0
UbaPI	cgaacg	6	0	0	0	0	0	0
UnbI	ggncc	5	2	0	-1	5	0	0
Van91I	CCANNNNNTGG	11	2	0	7	4	0	0
Vha464I	CTTAAG	6	2	0	1	5	0	0
VneI	GTGCAC	6	2	0	1	5	0	0
VpaK11AI	ggwcc	5	2	0	-1	5	0	0
VpaK11BI	GGWCC	5	2	0	1	4	0	0
VspI	ATTAAT	6	2	0	2	4	0	0
XagI	CCTNNNNNAGG	11	2	0	5	6	0	0
XapI	RAATTY	6	2	0	1	5	0	0
XbaI	TCTAGA	6	2	0	1	5	0	0
XceI	RCATGY	6	2	0	5	1	0	0
XcmI	CCANNNNNNNNNTGG	15	2	0	8	7	0	0
XhoI	CTCGAG	6	2	0	1	5	0	0
XhoII	RGATCY	6	2	0	1	5	0	0
XmaI	CCCGGG	6	2	0	1	5	0	0
XmaIII	cggccg	6	2	0	1	5	0	0
XmaCI	CCCGGG	6	2	0	1	5	0	0
XmaJI	CCTAGG	6	2	0	1	5	0	0
XmiI	GTMKAC	6	2	0	2	4	0	0
XmnI	GAANNNNTTC	10	2	1	5	5	0	0
XspI	CTAG	4	2	0	1	3	0	0
ZraI	GACGTC	6	2	1	3	3	0	0
ZrmI	AGTACT	6	2	1	3	3	0	0
Zsp2I	ATGCAT	6	2	0	5	1	0	0