#!/usr/bin/perl

use MongoDB;
use Text::CSV;
use Data::Dumper;
use Lingua::EN::Nums2Words;
use Time::HiRes qw/ time /;
use POSIX;

my $csv = Text::CSV->new({binary => 1}) or die "Cannot use CSV: ".Text::CSV->error_diag();

my $client = MongoDB::MongoClient->new(host => 'localhost', port => 27017);
my $database = $client->get_database('test');
my $collection = $database->get_collection('posts');

my $start = time();

my $rowCount = 0;
my $columnCount = 0;
my $columnTitles = undef;
open(my $fh, "<".$ENV{"HOME"}."/Desktop/data.csv");
while (my $row = $csv->getline($fh)) {
	$rowCount++;
	if ($rowCount==1) {
		$columnCount = scalar(@$row);
		$columnTitles = $row;
		next;
	}
	my $data = {};
	for (my $i=0; $i<$columnCount; $i++) {
		$data->{$columnTitles->[$i]} = $row->[$i];
	}
	$data->{'id'} = $rowCount-1;
	$collection->insert($data);
}
$csv->eof or $csv->error_diag();
close($fh);

my $runTime = sprintf("%.5f", time()-$start);
print "Insert ".$rowCount." rows: ".$runTime."\n";

my $start = time();
$collection->ensure_index({"data" => "text"}, {"name" => "data_index"});

while (1) {
	eval {
		my $result = $database->eval("db.currentOp()");
	};
	unless ($@) {
		last;
	}
}

my $runTime = sprintf("%.5f", time()-$start);
print "Create index: ".$runTime."\n";

my $start = time();
my $result = $database->eval("db.posts.runCommand('text', {search: 'feet'});");
my $runTime = sprintf("%.5f", time()-$start);
print "Search Index: ".$runTime."\n";

my $start = time();
my $result = $collection->find({"data" => {"\$regex" => "feet"}})->limit(100);
while (my $row = $result->next) {
	#Do nothing
}
my $runTime = sprintf("%.5f", time()-$start);
print "Find by string contains: ".$runTime."\n";

my $start = time();
my $result = $collection->find({"id" => 584});
while (my $row = $result->next) {
	#Do nothing
}
my $runTime = sprintf("%.5f", time()-$start);
print "Find by id: ".$runTime."\n";

$collection->drop();

my $collection = $database->get_collection('t1');

my $start = time();
for (my $i=0; $i<1000; $i++) {
	my $number = $i*135;
	$collection->insert({"a" => $i, "b" => $number, "c" => num2word($number)});
}
my $runTime = sprintf("%.5f", time()-$start);
print "1000 INSERTs: ".$runTime."\n";

my $collection = $database->get_collection('t2');

my $start = time();
for (my $i=0; $i<25000; $i++) {
	my $number = $i*135;
	$collection->insert({"a" => $i, "b" => $number, "c" => num2word($number)});
}
my $runTime = sprintf("%.5f", time()-$start);
print "25000 INSERTs in a transaction: ".$runTime."\n";

my $collection = $database->get_collection('t3');
$collection->ensure_index({"c" => 1}, {"name" => "c_index"});

my $start = time();
for (my $i=0; $i<25000; $i++) {
	my $number = $i*135;
	$collection->insert({"a" => $i, "b" => $number, "c" => num2word($number)});
}
my $runTime = sprintf("%.5f", time()-$start);
print "25000 INSERTs into an indexed table: ".$runTime."\n";

my $collection = $database->get_collection('t2');
my $start = time();
for (my $i=0; $i<100; $i++) {
	my $number = $i*100;
	my $result = $collection->aggregate([{"\$match" => {"b" => {"\$gte" => $number, "\$lt" => $number+1000}}}, {"\$group" => {"_id" => 0, "average" => {"\$avg" => "\$b"}, "count" => {"\$sum" => 1}}}]);
}
my $runTime = sprintf("%.5f", time()-$start);
print "100 SELECTs without an index: ".$runTime."\n";

my $collection = $database->get_collection('t2');
my $start = time();
for (my $i=0; $i<100; $i++) {
	my $number = $i;
	my $result = $collection->aggregate([{"\$match" => {"c" => {"\$regex" => num2word($number)}}}, {"\$group" => {"_id" => 0, "average" => {"\$avg" => "\$b"}, "count" => {"\$sum" => 1}}}]);
}
my $runTime = sprintf("%.5f", time()-$start);
print "100 SELECTs on a string comparison: ".$runTime."\n";

my $collection = $database->get_collection('t2');
my $start = time();
$collection->ensure_index({"a" => 1}, {"name" => "a_index"});
$collection->ensure_index({"b" => 1}, {"name" => "b_index"});
my $runTime = sprintf("%.5f", time()-$start);
print "Creating an index: ".$runTime."\n";

my $collection = $database->get_collection('t2');
my $start = time();
for (my $i=0; $i<5000; $i++) {
	my $number = $i*100;
	my $result = $collection->aggregate([{"\$match" => {"b" => {"\$gte" => $number, "\$lt" => $number+100}}}, {"\$group" => {"_id" => 0, "average" => {"\$avg" => "\$b"}, "count" => {"\$sum" => 1}}}]);
}
my $runTime = sprintf("%.5f", time()-$start);
print "5000 SELECTs with an index: ".$runTime."\n";

my $collection = $database->get_collection('t1');
my $start = time();
for (my $i=0; $i<1000; $i++) {
	my $number = $i*10;
	my $result = $collection->find({"b" => {"\$gte" => $number, "\$lt" => $number+10}});
	while (my $row = $result->next) {
		$collection->update({"_id" => $row->{'_id'}}, {'$set' => {'b' => $row->{'b'}*2}});
	}
}
my $runTime = sprintf("%.5f", time()-$start);
print "1000 UPDATEs without an index: ".$runTime."\n";

my $collection = $database->get_collection('t2');
my $start = time();
for (my $i=0; $i<25000; $i++) {
	my $number = $i*123;
	$collection->update({"a" => $i}, {'$set' => {'b' => $number}});
}
my $runTime = sprintf("%.5f", time()-$start);
print "25000 UPDATEs with an index: ".$runTime."\n";

my $collection = $database->get_collection('t2');
my $start = time();
for (my $i=0; $i<25000; $i++) {
	my $number = $i*123;
	$collection->update({"a" => $i}, {'$set' => {'c' => num2word($number)}});
}
my $runTime = sprintf("%.5f", time()-$start);
print "25000 text UPDATEs with an index: ".$runTime."\n";

my $start = time();
$database->eval("db.t2.find().forEach(function(x){db.t1.insert({a: x['b'],b: x['a'],c: x['c']})});");
$database->eval("db.t1.find().forEach(function(x){db.t2.insert({a: x['b'],b: x['a'],c: x['c']})});");
my $runTime = sprintf("%.5f", time()-$start);
print "INSERTs from a SELECT: ".$runTime."\n";

my $collection = $database->get_collection('t2');
my $start = time();
$collection->remove({"c" => {"\$regex" => "FIFTY"}});
my $runTime = sprintf("%.5f", time()-$start);
print "DELETE without an index: ".$runTime."\n";

my $collection = $database->get_collection('t2');
my $start = time();
$collection->remove({"a" => {"\$gt" => 10, "\$lt" => 20000}});
my $runTime = sprintf("%.5f", time()-$start);
print "DELETE with an index: ".$runTime."\n";

my $start = time();
$database->eval("db.t1.find().forEach(function(x){db.t2.insert(x)});");
my $runTime = sprintf("%.5f", time()-$start);
print "A big INSERT after a big DELETE: ".$runTime."\n";

my $collection = $database->get_collection('t1');
my $start = time();
$collection->remove();
for (my $i=0; $i<12000; $i++) {
	my $number = $i*165;
	$collection->insert({"a" => $i, "b" => $number, "c" => num2word($number)});
}
my $runTime = sprintf("%.5f", time()-$start);
print "A big DELETE followed by many small INSERTs: ".$runTime."\n";

my $start = time();
my $collection = $database->get_collection('t1');
$collection->drop();
my $collection = $database->get_collection('t2');
$collection->drop();
my $collection = $database->get_collection('t3');
$collection->drop();
my $runTime = sprintf("%.5f", time()-$start);
print "DROP TABLE: ".$runTime."\n";

sub hex2bin {
	my $h = shift;
	my $hlen = length($h);
	return pack("H$hlen", $h);
}

my $collection = $database->get_collection('ips');
for (my $i=0; $i<10; $i++) {
	my $binary = hex2bin("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".$i."0");
	my $binaryEnd = hex2bin("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".$i."F");
	$collection->insert({"a" => $binary, "b" => $binaryEnd, "c" => $i})
}

my $correct = 1;
for (my $i=0; $i<10; $i++) {
	my $binary = hex2bin("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF".$i."5");
	my $result = $collection->find({"a" => {"\$lte" => $binary}, "b" => {"\$gte" => $binary}});
	my $row = $result->next;
	unless ($row->{'c'}==$i) {
		$correct = 0;
		print "Unable to find ".$i." ".$binary." in the database.\n";
	}
}
if ($correct) {
	print "Binary range seems to work.\n";
}
$collection->remove();

my $start = time();
for (my $a=0; $a<10; $a++) {
	for (my $b=0; $b<10; $b++) {
		for (my $c=0; $c<10; $c++) {
			for (my $d=0; $d<10; $d++) {
				for (my $e=0; $e<10; $e++) {
					for (my $f=0; $f<10; $f++) {
						for (my $g=0; $g<10; $g++) {
							my $binary = hex2bin("FFFFFFFFFFFFFFFF".$a."F".$b."F".$c."F".$d."F".$e."F".$f."F".$g."FF0");
							my $binaryEnd = hex2bin("FFFFFFFFFFFFFFFF".$a."F".$b."F".$c."F".$d."F".$e."F".$f."F".$g."FFF");
							$collection->insert({"a" => $binary, "b" => $binaryEnd})
						}
					}
				}
			}
		}
	}
}
my $runTime = sprintf("%.5f", time()-$start);
print "Insert large amount of test IP Addreses: ".$runTime."\n";

my $result = $database->run_command({"count" => "ips"});
print Dumper($result);

my $start = time();
my $binary = hex2bin("FFFFFFFFFFFFFFFF5F7F8F3F9F0F6FF4");
my $result = $collection->find({"a" => {"\$lte" => $binary}, "b" => {"\$gte" => $binary}});
my $row = $result->next;
print Dumper($row);
my $runTime = sprintf("%.5f", time()-$start);
print "Find one IP Address: ".$runTime."\n";

$collection->drop();