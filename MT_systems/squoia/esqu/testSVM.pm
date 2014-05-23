
package squoia::esqu::testSVM;
use utf8;
#use Storable;    # to retrieve hash from disk
#use open ':utf8';
#binmode STDIN, ':utf8';
#binmode(STDOUT, ":utf8");
#binmode(STDERR, ":utf8");
use strict;
use Algorithm::SVM;
use Algorithm::SVM::DataSet;
my $path = File::Basename::dirname(File::Spec::Functions::rel2abs($0));
my $localpath = $path."/models";

#my $svm1 =  new Algorithm::SVM(Model => 'svm_model_class7');
##my $svm2 =  new Algorithm::SVM(Model => 'svm_model_class6');
#my $svm2 =  new Algorithm::SVM(Model => 'svm_model_class6_nomPos_not_optimized');
#my $svm3 =  new Algorithm::SVM(Model => 'svm_model_class23');

#my $svm1 =  new Algorithm::SVM(Model => 'class7vsAll_prob.model');
#my $svm2 =  new Algorithm::SVM(Model => 'class6vsAll.model');
#my $svm3 =  new Algorithm::SVM(Model => 'class3vsAll.model');
#my $svm4 =  new Algorithm::SVM(Model => 'class2vsAll.model');

#my $svm =  new Algorithm::SVM(Model => 'ancoraAndiula_svm.model');

my $modelPath = "$localpath/ancoraAndiula_svm.model";
print STDERR "modelpath: $modelPath\n";
my $svm =  new Algorithm::SVM(Model => "$modelPath");
## in svm model:
# class 3 = 7 = finite
# class 1 = 3 = obligative
# class 0 = 2 = perfect
# class 2 = 6 = switch

my $correct=0;
my $incorrect=0;
my $stillAmb=0;
my $ambigs=0;

my %mapSVMClassToXmlClass = ( 3.0 => 7, 1.0 => 3, 0.0 => 2, 2.0 => 6);
	

sub main{
	my $testfile = $_[0];
	open (TEST, $testfile);
	while(<TEST>)
	{
		# with libsvm format
		my ( @data) = split('\s');
		my $class = @data[0];
		shift(@data);
		#print "class: $class \n";
		
		my $ds =  new Algorithm::SVM::DataSet(Label => 1);
		
		foreach my $d (@data){
			my ($index, $value ) = split(':',$d);
			$ds->attribute($index,$value);
		}
		
		#my @arr =$ds->asArray();
		#print STDERR "$_";
		#print STDERR "as array: @arr\n";
	
		my $result = $svm->predict($ds);
		
		if($result == $class){
			$correct++;
			#print STDERR "correct\n";
		}
	    elsif($stillAmb){
	    	$ambigs++;
	    	$stillAmb=0;
	    }
		else{
			$incorrect++;
			print STDERR "predicted: $result, class was $class, in xml $mapSVMClassToXmlClass{$result}\n";
			print STDERR "wrong\n";
		}
		
	}
	print "correct: $correct\n";
print "incorrect: $incorrect\n";
print "ambig: $ambigs\n";
}



#while(<>)
#{
#    # vector as input
#    unless(/^\%/){
#    	my ( @data) = split(',');
#    	pop(@data);
#    	my $ds =  new Algorithm::SVM::DataSet(Label => 1, Data => \@data);
#    	my $result = $svm->predict($ds);
#    	print STDERR "predicted: $result, in xml $mapSVMClassToXmlClass{$result}\n";
#    }
#}
	
	
	
	
	
	#my $p = $svm1->getSVRProbability($ds);
	#print STDERR "prob fuer svm1 (7: 3.0): $p, class $class\n";
#	my $result;	
#	# if svm2 return class 1 -> this is a switch form
#	if($svm2->predict($ds)){
#		#print STDERR "predicted switch (2), class is $class\n";
#		$result= 2.0;
#	}
#	# if svm4 return class 1 -> this is an perfect  form
#	elsif($svm4->predict($ds)){
#		#print STDERR "predicted perfect(0), class is $class\n";
#		$result= 0.0;
#	}
#
#	# if svm1 return class 1 -> this is a finite form
#	elsif($svm1->predict($ds)){
#		#my $p = $svm1->getSVRProbability($ds);
#		#print STDERR "predicted finite (3), class is $class\n";
#		$result= 3.0;
#	}
#	# if svm3 return class 1 -> this is an obligative  form
#	elsif($svm3->predict($ds)){
#		#print STDERR "predicted obligative (1), class is $class\n";
#		$result= 1.0;
#	}
#	
#
#	else{
#		#print STDERR "still ambiguous, class is $class\n";
#		$stillAmb=1;
#	}
#	


#
#my @v = (1,0,0,0,0,0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10);
#
#my $ds =  new Algorithm::SVM::DataSet(Label => 1,
#											 Data => \@v);
#	my $svmClass = $svm->predict($ds);
#	
#	print STDERR "predicted $svmClass, in xml: $mapSVMClassToXmlClass{$svmClass}\n";
#	print STDERR "vector: @v\n";

