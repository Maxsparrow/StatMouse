<?php 
$pageclass="champions";
include('inc/header.php');
include('model/champion.php');
?>
	
	<?php
	include('connections.php');
	
	$champion = $_GET['champion'];
	echo $champion;
	if(isset($_GET['pg'])){
		$page = $_GET['pg'];
	} else {
		$page = 0;
	}

	if(isset($_GET['numPerPage'])){
		$numPerPage = $_GET['numPerPage'];
	} else {
		$numPerPage = 5;
	}
	
	?>
	
	<div class="container">
		<?php 
		$champion = new Champion($champion); 
		echo "<h1 style='color:#000;font-weight:bold;'><img style='width:90px;' src='".$champion->GetImagePath()."' /> ";
		echo $champion->name;
		echo "</h1>";
		?>
		<table class="table-bordered">
		<thead>
		<th>Build Rank</th>
		<th>Build Win Rate</th>
		<th>Starting Items</th>
		<?php 
			for($i=1;$i<=9;$i+=1) {
				echo "<th>Back ".$i."</th>";
			}
		?>
		</thead>
		
		<?php
		for ($i=1;$i<=$numPerPage;$i+=1) {
			echo "<tr>";
			$query = "SELECT buildorder.*,champions.championName FROM buildorder LEFT JOIN champions ON buildorder.championId = champions.championId where championName = :champion AND analysisDate = '2015-02-08' AND buildrank = :build";
			$stmt = $db->prepare($query);
			$stmt->bindValue(':champion',$champion->name,PDO::PARAM_STR);
			$stmt->bindValue(':build',$i,PDO::PARAM_INT);
			$stmt->execute();
			$results = $stmt->fetchAll();
			echo "<td>".$results[1]['buildrank']."</td>";
			echo "<td>".round($results[1]['buildscore']*100,2)."%</td>";
			$lastordernum=0;
			echo "<td>";
			foreach($results as $row) {
				if($row['ordernum']>9) {break;}
				if($row['ordernum']>$lastordernum) {
					echo "</td><td>";
					$lastordernum=$row['ordernum'];
				}
				echo "<img style='height: 50%;' src='/img/item/".$row['itemId'].".png' />";			
			}
			echo "</tr>";
		}?>
		</table>

    	<?php
		//Pagination CBJ 12.10.14 (12.14.14 removed for now, only want to display a few per page)
		//	echo "<nav><ul class='pager'>";
		//	
		//		if ($page!=0) echo "<li class='previous'><a href='champion.php?champion=".htmlentities($champion->name, ENT_QUOTES)."&pg=".($page-1)."' style='color: black;'> Previous Page </a></li>";			
		//		if (count($results)>=$numPerPage) echo "<li class='next'><a href='champion.php?champion=".htmlentities($champion->name, ENT_QUOTES)."&pg=".($page+1)."' style='color: black;'> Next Page </a></li>";
		//		
		//	echo "</ul></nav>";
    	?>	
	</div>
		
	<?php 
	$db = null;
	?>
		
<?php include('inc/footer.php'); ?>