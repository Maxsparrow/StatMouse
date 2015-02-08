<?php $pageclass="index";
include('inc/header.php'); ?>

	</br></br>
	<div class="container jumbotron">

		<h2 style="font-size:50px"><strong>WE ARE IN DEVELOPMENT! LAUNCHING MAY 2015</strong></h2>

		<p>Welcome to StatMouse! Here we use statistics to help League of Legends players make the best item choices they can using adjusted win rate calculations. These calculations account for gold differentials between teams, so games where one team is way ahead won't count as much towards an item's winrate.</p>
        
        <p>Current data is available for patch 5.2 on the Champions tab. Find your champion by using the search box or the page buttons at the bottom of the champion page. Select your champion and best items will be shown for that champion on a scale from 0-10, 10 being the best. </p>
        
        <p><strong>Update 2/8/15:</strong> Build orders have now been implemented. They still need a lot of work but the structure is there, so I will be exploring different options to see what works best. The current build win rates do not account for gold differentials, but are a win rate for that 'cluster' of items, so any builds very similar to that one, even if they are a bit different are included in that win rate. Right now there are too many clusters so many builds are very similar.</p>


		<p><a class="btn btn-primary btn-lg" href="champions.php" role="button">Browse Champions</a></p>

	</div>
		
</div>
		
<?php include('inc/footer.php'); ?>