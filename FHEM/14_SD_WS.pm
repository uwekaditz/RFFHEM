##############################################
# $Id: 14_SD_WS.pm 33 2017-01-19 18:00:00Z v3.3-dev $
#
# The purpose of this module is to support serval
# weather sensors which use various protocol
# Sidey79 & Ralf9  2016 - 2017
#

package main;


use strict;
use warnings;

#use Data::Dumper;


sub SD_WS_Initialize($)
{
	my ($hash) = @_;

	$hash->{Match}		= '^W\d+x{0,1}#.*';
	$hash->{DefFn}		= "SD_WS_Define";
	$hash->{UndefFn}	= "SD_WS_Undef";
	$hash->{ParseFn}	= "SD_WS_Parse";
	$hash->{AttrFn}		= "SD_WS_Attr";
	$hash->{AttrList}	= "IODev do_not_notify:1,0 ignore:0,1 showtime:1,0 " .
						  "$readingFnAttributes ";
	$hash->{AutoCreate} =
	{ 
		"SD_WS37_TH.*" => { ATTR => "event-min-interval:.*:300 event-on-change-reading:.*", FILTER => "%NAME", GPLOT => "temp4hum4:Temp/Hum,",  autocreateThreshold => "2:180"},
		"SD_WS50_SM.*" => { ATTR => "event-min-interval:.*:300 event-on-change-reading:.*", FILTER => "%NAME", GPLOT => "temp4hum4:Temp/Hum,",  autocreateThreshold => "2:180"},
		"BresserTemeo.*" => { ATTR => "event-min-interval:.*:300 event-on-change-reading:.*", FILTER => "%NAME", GPLOT => "temp4hum4:Temp/Hum,", autocreateThreshold => "2:180"},
		"SD_WS51_TH.*" => { ATTR => "event-min-interval:.*:300 event-on-change-reading:.*", FILTER => "%NAME", GPLOT => "temp4hum4:Temp/Hum,", autocreateThreshold => "2:180"},
		"SD_WS58_TH.*" => { ATTR => "event-min-interval:.*:300 event-on-change-reading:.*", FILTER => "%NAME", GPLOT => "temp4hum4:Temp/Hum,", autocreateThreshold => "2:90"},
    "SD_WH2.*" => { ATTR => "event-min-interval:.*:300 event-on-change-reading:.*", FILTER => "%NAME", GPLOT => "temp4hum4:Temp/Hum,", autocreateThreshold => "2:90"},
	};

}




#############################
sub SD_WS_Define($$)
{
	my ($hash, $def) = @_;
	my @a = split("[ \t][ \t]*", $def);

	return "wrong syntax: define <name> SD_WS <code> ".int(@a) if(int(@a) < 3 );

	$hash->{CODE} = $a[2];
	$hash->{lastMSG} =  "";
	$hash->{bitMSG} =  "";

	$modules{SD_WS}{defptr}{$a[2]} = $hash;
	$hash->{STATE} = "Defined";

	my $name= $hash->{NAME};
	return undef;
}

#####################################
sub SD_WS_Undef($$)
{
	my ($hash, $name) = @_;
	delete($modules{SD_WS}{defptr}{$hash->{CODE}})
	if(defined($hash->{CODE}) && defined($modules{SD_WS}{defptr}{$hash->{CODE}}));
	return undef;
}


###################################
sub SD_WS_Parse($$)
{
	my ($iohash, $msg) = @_;
	#my $rawData = substr($msg, 2);
	my $name = $iohash->{NAME};
	my ($protocol,$rawData) = split("#",$msg);
	$protocol=~ s/^[WP](\d+)/$1/; # extract protocol
	

	my $dummyreturnvalue= "Unknown, please report";
	my $hlen = length($rawData);
	my $blen = $hlen * 4;
	my $bitData = unpack("B$blen", pack("H$hlen", $rawData));
	my $bitData2;
	
	my $model;	# wenn im elsif Abschnitt definiert, dann wird der Sensor per AutoCreate angelegt
	my $SensorTyp;
	my $id;
	my $bat;
	my $channel;
	my $rawTemp;
	my $temp;
	my $hum;
	my $trend;
	
	my %decodingSubs  = (
    50    => # Protocol 50
     # FF550545FF9E
     # FF550541FF9A 
	 # AABCDDEEFFGG
 	 # A = Preamble, always FF
 	 # B = TX type, always 5
 	 # C = Address (5/6/7) > low 2 bits = 1/2/3
 	 # D = Soil moisture 05% 
 	 # E = temperature 
 	 # F = security code, always F
 	 # G = Checksum 55+05+45+FF=19E CRC value = 9E
        {   # subs to decode this
        	sensortype => 'XT300',
        	model => 'SD_WS_50_SM',
			prematch => sub {my $msg = shift; return 1 if ($msg =~ /^FF5[0-9A-F]{5}FF[0-9A-F]{2}/); }, 		# prematch
			crcok => sub {my $msg = shift; return 1 if ((hex(substr($msg,2,2))+hex(substr($msg,4,2))+hex(substr($msg,6,2))+hex(substr($msg,8,2))&0xFF) == (hex(substr($msg,10,2))) );  }, 	# crc
			id => sub {my $msg = shift; return (hex(substr($msg,2,2)) &0x03 ); },   							#id
			temp => sub {my $msg = shift; return  ((hex(substr($msg,6,2)))-40)  },								#temp
			hum => sub {my $msg = shift; return hex(substr($msg,4,2));  }, 										#hum
			channel => sub {my (undef,$bitData) = @_; return ( SD_WS_binaryToNumber($bitData,12,15)&0x03 );  }, #channel
			bat 	=> sub { return "";},
        },	
     33 =>
   	 	 {
     		sensortype => 's014/TFA 30.3200/TCM/Conrad',
        	model =>	'SD_WS_33_TH',
			prematch => sub {my $msg = shift; return 1 if ($msg =~ /^[0-9A-F]{10,11}/); }, 							# prematch
			crcok => 	sub {return SD_WS_binaryToNumber($bitData,36,39)+1;  }, 									# crc currently not calculated
			id => 		sub {my (undef,$bitData) = @_; return SD_WS_binaryToNumber($bitData,0,9); },   				# id
	#		sendmode =>	sub {my (undef,$bitData) = @_; return SD_WS_binaryToNumber($bitData,10,11) eq "1" ? "manual" : "auto";  }
			temp => 	sub {my (undef,$bitData) = @_; return (((SD_WS_binaryToNumber($bitData,22,25)*256 +  SD_WS_binaryToNumber($bitData,18,21)*16 + SD_WS_binaryToNumber($bitData,14,17)) *10 -12200) /18)/10;  },	#temp
			hum => 		sub {my (undef,$bitData) = @_; return (SD_WS_binaryToNumber($bitData,30,33)*16 + SD_WS_binaryToNumber($bitData,26,29));  }, 					#hum
			channel => 	sub {my (undef,$bitData) = @_; return (SD_WS_binaryToNumber($bitData,12,13)+1 );  }, 		#channel
     		bat => 		sub {my (undef,$bitData) = @_; return SD_WS_binaryToNumber($bitData,34) eq "1" ? "ok" : "critical";},
    # 		sync => 	sub {my (undef,$bitData) = @_; return (SD_WS_binaryToNumber($bitData,35,35) eq "1" ? "true" : "false");},
   	 	 } ,       
     51 =>
   	 	 {
     		sensortype => 'Lidl Wetterstation 2759001/IAN114324',
        	model =>	'SD_WS_51_TH', 
			prematch => sub {my $msg = shift; return 1 if ($msg =~ /^[0-9A-F]{10}/); }, 							# prematch
			crcok => 	sub {return 1;  }, 																			# crc is unknown
			id => 		sub {my (undef,$bitData) = @_; return SD_WS_binaryToNumber($bitData,0,12); },   				# random id?
	#		sendmode =>	sub {my (undef,$bitData) = @_; return SD_WS_binaryToNumber($bitData,10,11) eq "1" ? "manual" : "auto";  }
			temp => 	sub {my (undef,$bitData) = @_; return round(((SD_WS_binaryToNumber($bitData,16,27)) -1220) *5 /90.0,1); },	#temp
			hum => 		sub {my (undef,$bitData) = @_; return (SD_WS_binaryToNumber($bitData,28,31)*10) + (SD_WS_binaryToNumber($bitData,32,35));  }, 		#hum
			channel => 	sub {my (undef,$bitData) = @_; return (SD_WS_binaryToNumber($bitData,36,39) );  }, 		#channel
     		bat => 		sub {my (undef,$bitData) = @_; return SD_WS_binaryToNumber($bitData,13) eq "1" ? "crititcal" : "ok";},
      		trend => 	sub {my (undef,$bitData) = @_; return SD_WS_binaryToNumber($bitData,15,16) eq "01" ? "rising" : SD_WS_binaryToNumber($bitData,14,15) eq "00" ? "neutral" : "rising";},
     # 		sync => 	sub {my (undef,$bitData) = @_; return (SD_WS_binaryToNumber($bitData,35,35) eq "1" ? "true" : "false");},
   	 	 }   ,  
       58 => 
   	 	 {
     		sensortype => 'TFA 3032080',
        	model =>	'SD_WS_58_TH', 
			prematch => sub {my $msg = shift; return 1 if ($msg =~ /^45[0-9A-F]{11}/); }, 							# prematch
			crcok => 	sub {   my $msg = shift;
							    my @buff = split(//,substr($msg,index($msg,"45"),10));
							    my $crc_check = substr($msg,index($msg,"45")+10,2);
							    my $mask = 0x7C;
							    my $checksum = 0x64;
							    my $data;
							    my $nibbleCount;
							    for ( $nibbleCount=0; $nibbleCount < scalar @buff; $nibbleCount+=2)
							    {
							        my $bitCnt;
							        if ($nibbleCount+1 <scalar @buff)
							        {
							        	$data = hex($buff[$nibbleCount].$buff[$nibbleCount+1]);
							        } else  {
							        	$data = hex($buff[$nibbleCount]);	
							        }
							        for ( my $bitCnt= 7; $bitCnt >= 0 ; $bitCnt-- )
							        {
							            my $bit;
							            # Rotate mask right
							            $bit = $mask & 1;
							            $mask = ($mask >> 1 ) | ($mask << 7) & 0xFF;
							            if ( $bit )
							            {
							                $mask ^= 0x18 & 0xFF;
							            }
							            # XOR mask into checksum if data bit is 1
							            if ( $data & 0x80 )
							            {
							                $checksum ^= $mask & 0xFF;
							            }
							            $data <<= 1 & 0xFF;
							        }
							    }
							    if ($checksum == hex($crc_check)) {
								    return 1;
							    } else {
							    	return 0;
							    }
							}, 																			
			id => 		sub {my (undef,$bitData) = @_; return SD_WS_binaryToNumber($bitData,8,15); },   							   # random id
			bat => 		sub {my (undef,$bitData) = @_; return SD_WS_binaryToNumber($bitData,16) eq "1" ? "crititcal" : "ok";},  	   # bat?
			channel => 	sub {my (undef,$bitData) = @_; return (SD_WS_binaryToNumber($bitData,17,19)+1 );  },						   # channel
			temp => 	sub {my (undef,$bitData) = @_; return round((SD_WS_binaryToNumber($bitData,20,31)-720)*0.0556,1); }, 		   # temp
			hum => 		sub {my (undef,$bitData) = @_; return (SD_WS_binaryToNumber($bitData,32,39));  }, 							   # hum
   	 	 }   ,     
    );
    
    	
	Log3 $name, 4, "SD_WS_Parse: Protocol: $protocol, rawData: $rawData";
	
	if ($protocol eq "37")		# Bresser 7009994
	{
		# 0      7 8 9 10 12        22   25    31
		# 01011010 0 0 01 01100001110 10 0111101 11001010
		# ID      B? T Kan Temp       ?? Hum     Pruefsumme?
		
		# MU;P0=729;P1=-736;P2=483;P3=-251;P4=238;P5=-491;D=010101012323452323454523454545234523234545234523232345454545232345454545452323232345232340;CP=4;
		
		$model = "SD_WS37_TH";
		$SensorTyp = "Bresser 7009994";
	
		$id = 		SD_WS_binaryToNumber($bitData,0,7);
		#$bat = 	int(substr($bitData,8,1)) eq "1" ? "ok" : "low";
		$channel = 	SD_WS_binaryToNumber($bitData,10,11);
		$rawTemp = 	SD_WS_binaryToNumber($bitData,12,22);
		$hum =		SD_WS_binaryToNumber($bitData,25,31);
		
		$id = sprintf('%02X', $id);           # wandeln nach hex
		$temp = ($rawTemp - 609.93) / 9.014;
		$temp = sprintf("%.1f", $temp);
		
		if ($hum < 10 || $hum > 99 || $temp < -30 || $temp > 70) {
			return "";
		}
	
		$bitData2 = substr($bitData,0,8) . ' ' . substr($bitData,8,4) . ' ' . substr($bitData,12,11);
		$bitData2 = $bitData2 . ' ' . substr($bitData,23,2) . ' ' . substr($bitData,25,7) . ' ' . substr($bitData,32,8);
		Log3 $iohash, 4, "$name converted to bits: " . $bitData2;
		Log3 $iohash, 4, "$name decoded protocolid: $protocol ($SensorTyp) sensor id=$id, channel=$channel, rawTemp=$rawTemp, temp=$temp, hum=$hum";
	}
	elsif  ($protocol eq "44" || $protocol eq "44x")	# BresserTemeo
	{
		# 0    4    8    12       20   24   28   32   36   40   44       52   56   60
		# 0101 0111 1001 00010101 0010 0100 0001 1010 1000 0110 11101010 1101 1011 1110 110110010
		# hhhh hhhh ?bcc viiiiiii sttt tttt tttt xxxx xxxx ?BCC VIIIIIII Syyy yyyy yyyy

		# - h humidity / -x checksum
		# - t temp     / -y checksum
		# - c Channel  / -C checksum
		# - V sign     / -V checksum
		# - i 7 bit random id (aendert sich beim Batterie- und Kanalwechsel)  / - I checksum
		# - b battery indicator (0=>OK, 1=>LOW)               / - B checksum
		# - s Test/Sync (0=>Normal, 1=>Test-Button pressed)   / - S checksum
	
		$model= "BresserTemeo";
		$SensorTyp = "BresserTemeo";
		
		#my $binvalue = unpack("B*" ,pack("H*", $rawData));
		my $binvalue = $bitData;
 
		if (length($binvalue) != 72) {
			Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: length error (72 bits expected)!!!";
			return "";
		}

		# Check what Humidity Prefix (*sigh* Bresser!!!) 
		if ($protocol eq "44")
		{
			$binvalue = "0".$binvalue;
			Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: Humidity <= 79  Flag";
		}
		else
		{
			$binvalue = "1".$binvalue;
			Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: Humidity > 79  Flag";
		}
		
		Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: new bin $binvalue";
	
		my $checksumOkay = 1;
		
		my $hum1Dec = SD_WS_binaryToNumber($binvalue, 0, 3);
		my $hum2Dec = SD_WS_binaryToNumber($binvalue, 4, 7);
		my $checkHum1 = SD_WS_binaryToNumber($binvalue, 32, 35) ^ 0b1111;
		my $checkHum2 = SD_WS_binaryToNumber($binvalue, 36, 39) ^ 0b1111;

		if ($checkHum1 != $hum1Dec || $checkHum2 != $hum2Dec)
		{
			Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: checksum error in Humidity";
		}
		else
		{
			$hum = $hum1Dec.$hum2Dec;
			if ($hum < 1 || $hum > 100)
			{
				Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: Humidity Error. Humidity=$hum";
				return "";
			}
		}

		my $temp1Dec = SD_WS_binaryToNumber($binvalue, 21, 23);
		my $temp2Dec = SD_WS_binaryToNumber($binvalue, 24, 27);
		my $temp3Dec = SD_WS_binaryToNumber($binvalue, 28, 31);
		my $checkTemp1 = SD_WS_binaryToNumber($binvalue, 53, 55) ^ 0b111;
		my $checkTemp2 = SD_WS_binaryToNumber($binvalue, 56, 59) ^ 0b1111;
		my $checkTemp3 = SD_WS_binaryToNumber($binvalue, 60, 63) ^ 0b1111;
		$temp = $temp1Dec.$temp2Dec.".".$temp3Dec;
		
		if ($checkTemp1 != $temp1Dec || $checkTemp2 != $temp2Dec || $checkTemp3 != $temp3Dec)
		{
			Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: checksum error in Temperature";
			$checksumOkay = 0;
		}

		if ($temp > 60)
		{
			Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: Temperature Error. temp=$temp";
			return "";
		}
		
		my $sign = substr($binvalue,12,1);
		my $checkSign = substr($binvalue,44,1) ^ 0b1;
		
		if ($sign != $checkSign) 
		{
			Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: checksum error in Sign";
			$checksumOkay = 0;
		}
		else
		{
			if ($sign)
			{
				$temp = 0 - $temp
			}
		}
		
		$bat = substr($binvalue,9,1);
		my $checkBat = substr($binvalue,41,1) ^ 0b1;
		
		if ($bat != $checkBat)
		{
			Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: checksum error in Bat";
			$bat = undef;
		}
		else
		{
			$bat = ($bat == 0) ? "ok" : "low";
		}
		
		$channel = SD_WS_binaryToNumber($binvalue, 10, 11);
		my $checkChannel = SD_WS_binaryToNumber($binvalue, 42, 43) ^ 0b11;
		$id = SD_WS_binaryToNumber($binvalue, 13, 19);
		my $checkId = SD_WS_binaryToNumber($binvalue, 45, 51) ^ 0b1111111;
		
		if ($channel != $checkChannel || $id != $checkId)
		{
			Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: checksum error in Channel or Id";
			$checksumOkay = 0;
		}
		
		if ($checksumOkay == 0)
		{
			Log3 $iohash, 4, "SD_WS_Parse BresserTemeo: checksum error!!! These Values seem incorrect: temp=$temp, channel=$channel, id=$id";
			return "";
		}
		
		$id = sprintf('%02X', $id);           # wandeln nach hex
		Log3 $iohash, 4, "$name SD_WS_Parse: model=$model, temp=$temp, hum=$hum, channel=$channel, id=$id, bat=$bat";
		
	}   elsif  ($protocol eq "64")	# WH2
  {
  #* Fine Offset Electronics WH2 Temperature/Humidity sensor protocol
 #* aka Agimex Rosenborg 66796 (sold in Denmark)
 #* aka ClimeMET CM9088 (Sold in UK)
 #* aka TFA Dostmann/Wertheim 30.3157 (Temperature only!) (sold in Germany)
 #* aka ...
 #*
 #* The sensor sends two identical packages of 48 bits each ~48s. The bits are PWM modulated with On Off Keying
 # * The data is grouped in 6 bytes / 12 nibbles
 #* [pre] [pre] [type] [id] [id] [temp] [temp] [temp] [humi] [humi] [crc] [crc]
 #*
 #* pre is always 0xFF
 #* type is always 0x4 (may be different for different sensor type?)
 #* id is a random id that is generated when the sensor starts
 #* temp is 12 bit signed magnitude scaled by 10 celcius
 #* humi is 8 bit relative humidity percentage
 #* Based on reverse engineering with gnu-radio and the nice article here:
 #*  http://lucsmall.com/2012/04/29/weather-station-hacking-part-2/
 # 0x4A/74 0x70/112 0xEF/239 0xFF/255 0x97/151 | Sensor ID: 0x4A7 | 255% | 239 | OK
 #{ Dispatch($defs{sduino}, "W64#4A70EFFF97", undef) }

        #* Message Format:
       #* .- [0] -. .- [1] -. .- [2] -. .- [3] -. .- [4] -.
       #* |       | |       | |       | |       | |       |
       #* SSSS.DDDD DDN_.TTTT TTTT.TTTT WHHH.HHHH CCCC.CCCC
       #* |  | |     ||  |  | |  | |  | ||      | |       |
       #* |  | |     ||  |  | |  | |  | ||      | `--------- CRC
       #* |  | |     ||  |  | |  | |  | |`-------- Humidity
       #* |  | |     ||  |  | |  | |  | |
       #* |  | |     ||  |  | |  | |  | `---- weak battery
       #* |  | |     ||  |  | |  | |  |
       #* |  | |     ||  |  | |  | `----- Temperature T * 0.1
       #* |  | |     ||  |  | |  |
       #* |  | |     ||  |  | `---------- Temperature T * 1
       #* |  | |     ||  |  |
       #* |  | |     ||  `--------------- Temperature T * 10
       #* |  | |     | `--- new battery
       #* |  | `---------- ID
       #* `---- START = 9
       #*
       #*/ 
       
       
   	Log3 $iohash, 4, "$name converted to bits: WH2 " . $bitData;    
    $model = "SD_WS_WH2";
		$SensorTyp = "WH2";
	  $id = 	SD_WS_bin2dec(substr($bitData,0,12));
    $id = sprintf('%03X', $id); 
	 	$channel = 	0;
    $bat =  	SD_WS_bin2dec(substr($bitData,20,1));
   	$temp = (SD_WS_bin2dec(substr($bitData,12,12))) / 10;
    Log3 $iohash, 4, "$name decoded protocolid: $protocol ($SensorTyp) sensor id=$id, Data:".substr($bitData,12,12)." temp=$temp";
    $hum =  SD_WS_bin2dec(substr($bitData,24,8));
    Log3 $iohash, 4, "$name decoded protocolid: $protocol ($SensorTyp) sensor id=$id, Data:".substr($bitData,24,8)." hum=$hum";
       
    Log3 $iohash, 4, "$name decoded protocolid: $protocol ($SensorTyp) sensor id=$id, channel=$channel, temp=$temp, hum=$hum";
    	
  #if ($hum < 0 || $hum > 100 || $temp < -40 || $temp > 70) {
	#		return "";
	#	}
	
 	 }
	elsif (defined($decodingSubs{$protocol}))		# durch den hash decodieren
	{
	 	   	$SensorTyp=$decodingSubs{$protocol}{sensortype};
		    if (!$decodingSubs{$protocol}{prematch}->( $rawData ))
		    { 
		   		Log3 $iohash, 4, "$name decoded protocolid: $protocol ($SensorTyp) prematch error" ;
		    	return "";  
	    	}
		    my $retcrc=$decodingSubs{$protocol}{crcok}->( $rawData );
		    if (!$retcrc)		    { 
		    	Log3 $iohash, 4, "$name decoded protocolid: $protocol ($SensorTyp) crc error: $retcrc";
		    	return "";  
	    	}
	    	$id=$decodingSubs{$protocol}{id}->( $rawData,$bitData );
	    	#my $temphex=$decodingSubs{$protocol}{temphex}->( $rawData,$bitData );
	    	
	    	$temp=$decodingSubs{$protocol}{temp}->( $rawData,$bitData );
	    	$hum=$decodingSubs{$protocol}{hum}->( $rawData,$bitData );
	    	$channel=$decodingSubs{$protocol}{channel}->( $rawData,$bitData );
	    	$model = $decodingSubs{$protocol}{model};
	    	$bat = $decodingSubs{$protocol}{bat}->( $rawData,$bitData );
	    	$trend = $decodingSubs{$protocol}{trend}->( $rawData,$bitData ) if (defined($decodingSubs{$protocol}{trend}));

	    	Log3 $iohash, 4, "$name decoded protocolid: $protocol ($SensorTyp) sensor id=$id, channel=$channel, temp=$temp, hum=$hum, bat=$bat";
		
	} 
	else {
		Log3 $iohash, 4, "SD_WS_Parse: unknown message, please report. converted to bits: $bitData";
		return undef;
	}


	if (!defined($model)) {
		return undef;
	}
	
	my $deviceCode;
	
	my $longids = AttrVal($iohash->{NAME},'longids',0);
	if (($longids ne "0") && ($longids eq "1" || $longids eq "ALL" || (",$longids," =~ m/,$model,/)))
	{
		$deviceCode = $model . '_' . $id . $channel;
		Log3 $iohash,4, "$name using longid: $longids model: $model";
	} else {
		$deviceCode = $model . "_" . $channel;
	}
	
	#print Dumper($modules{SD_WS}{defptr});
	
	my $def = $modules{SD_WS}{defptr}{$iohash->{NAME} . "." . $deviceCode};
	$def = $modules{SD_WS}{defptr}{$deviceCode} if(!$def);

	if(!$def) {
		Log3 $iohash, 1, 'SD_WS: UNDEFINED sensor ' . $model . ' detected, code ' . $deviceCode;
		return "UNDEFINED $deviceCode SD_WS $deviceCode";
	}
	#Log3 $iohash, 3, 'SD_WS: ' . $def->{NAME} . ' ' . $id;
	
	my $hash = $def;
	$name = $hash->{NAME};
	return "" if(IsIgnored($name));
	
	Log3 $name, 4, "SD_WS: $name ($rawData)";  

	if (!defined(AttrVal($hash->{NAME},"event-min-interval",undef)))
	{
		my $minsecs = AttrVal($iohash->{NAME},'minsecs',0);
		if($hash->{lastReceive} && (time() - $hash->{lastReceive} < $minsecs)) {
			Log3 $hash, 4, "$deviceCode Dropped due to short time. minsecs=$minsecs";
			return "";
		}
	}

	$hash->{lastReceive} = time();
	$hash->{lastMSG} = $rawData;
	if (defined($bitData2)) {
		$hash->{bitMSG} = $bitData2;
	} else {
		$hash->{bitMSG} = $bitData;
	}

	my $state = "T: $temp" . (($hum > 0 && $hum < 100) ? " H: $hum":"");

	readingsBeginUpdate($hash);
	readingsBulkUpdate($hash, "state", $state);
	readingsBulkUpdate($hash, "temperature", $temp)  if (defined($temp));
	readingsBulkUpdate($hash, "humidity", $hum)  if (defined($hum) && ($hum > 0 && $hum < 100 )) ;
	readingsBulkUpdate($hash, "battery", $bat) if (defined($bat) && length($bat) > 0) ;
	readingsBulkUpdate($hash, "channel", $channel) if (defined($channel)&& length($channel) > 0);
	readingsBulkUpdate($hash, "trend", $trend) if (defined($trend) && length($trend) > 0);
	
	readingsEndUpdate($hash, 1); # Notify is done by Dispatch
	
	return $name;

}

sub SD_WS_Attr(@)
{
	my @a = @_;
	
	# Make possible to use the same code for different logical devices when they
	# are received through different physical devices.
	return  if($a[0] ne "set" || $a[2] ne "IODev");
	my $hash = $defs{$a[1]};
	my $iohash = $defs{$a[3]};
	my $cde = $hash->{CODE};
	delete($modules{SD_WS}{defptr}{$cde});
	$modules{SD_WS}{defptr}{$iohash->{NAME} . "." . $cde} = $hash;
	return undef;
}

sub SD_WS_bin2dec($)
    {
      my $h = shift;
      my $int = unpack("N", pack("B32",substr("0" x 32 . $h, -32))); 
      return sprintf("%d", $int); 
    }


sub SD_WS_binaryToNumber
{
	my $binstr=shift;
	my $fbit=shift;
	my $lbit=$fbit;
	$lbit=shift if @_;
	
	return oct("0b".substr($binstr,$fbit,($lbit-$fbit)+1));
}

1;

=pod
=item summary    Supports various weather stations
=item summary_DE Unterst&uumltzt verschiedene Funk Wetterstationen
=begin html

<a name="SD_WS"></a>
<h3>Weather Sensors various protocols</h3>
<ul>
  The SD_WS module interprets temperature sensor messages received by a Device like CUL, CUN, SIGNALduino etc.<br>
  <br>
  <b>Known models:</b>
  <ul>
    <li>Bresser 7009994</li>
    <li>Opus XT300</li>
  </ul>
  <br>
  New received device are add in fhem with autocreate.
  <br><br>

  <a name="SD_WS_Define"></a>
  <b>Define</b> 
  <ul>The received devices created automatically.<br>
  The ID of the defice is the cannel or, if the longid attribute is specified, it is a combination of channel and some random generated bits at powering the sensor and the channel.<br>
  If you want to use more sensors, than channels available, you can use the longid option to differentiate them.
  </ul>
  <br>
  <a name="SD_WS Events"></a>
  <b>Generated readings:</b>
  <br>Some devices may not support all readings, so they will not be presented<br>
  <ul>
  	 <li>State (T: H:)</li>
     <li>temperature (&deg;C)</li>
     <li>humidity: (The humidity (1-100 if available)</li>
     <li>battery: (low or ok)</li>
     <li>channel: (The Channelnumber (number if)</li>
  </ul>
  <br>
  <b>Attributes</b>
  <ul>
    <li><a href="#do_not_notify">do_not_notify</a></li>
    <li><a href="#ignore">ignore</a></li>
    <li><a href="#showtime">showtime</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>

  <a name="SD_WS_Set"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="SD_WS_Parse"></a>
  <b>Set</b> <ul>N/A</ul><br>

</ul>

=end html

=begin html_DE

<a name="SD_WS"></a>
<h3>SD_WS</h3>
<ul>
  Das SD_WS Modul verarbeitet von einem IO Ger&aumlt (CUL, CUN, SIGNALDuino, etc.) empfangene Nachrichten von Temperatur-Sensoren.<br>
  <br>
  <b>Unterst&uumltzte Modelle:</b>
  <ul>
    <li>Bresser 7009994</li>
    <li>Opus XT300</li>
    <li>BresserTemeo</li>
  </ul>
  <br>
  Neu empfangene Sensoren werden in FHEM per autocreate angelegt.
  <br><br>

  <a name="SD_WS_Define"></a>
  <b>Define</b> 
  <ul>Die empfangenen Sensoren werden automatisch angelegt.<br>
  Die ID der angelgten Sensoren ist entweder der Kanal des Sensors, oder wenn das Attribut longid gesetzt ist, dann wird die ID aus dem Kanal und einer Reihe von Bits erzeugt, welche der Sensor beim Einschalten zuf&aumlllig vergibt.<br>
  </ul>
  <br>
  <a name="SD_WS Events"></a>
  <b>Generierte Readings:</b>
  <ul>
  	 <li>State (T: H:)</li>
     <li>temperature (&deg;C)</li>
     <li>humidity: (Luftfeuchte (1-100)</li>
     <li>battery: (low oder ok)</li>
     <li>channel: (Der Sensor Kanal)</li>
  </ul>
  <br>
  <b>Attribute</b>
  <ul>
    <li><a href="#do_not_notify">do_not_notify</a></li>
    <li><a href="#ignore">ignore</a></li>
    <li><a href="#showtime">showtime</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>
  </ul>

  <a name="SD_WS_Set"></a>
  <b>Set</b> <ul>N/A</ul><br>

  <a name="SD_WS_Parse"></a>
  <b>Set</b> <ul>N/A</ul><br>

</ul>

=end html_DE
=cut
