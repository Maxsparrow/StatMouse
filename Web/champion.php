<?php include('inc/header.php');
include('model/champion.php');
?>
	
	<?php
	include('connections.php');
	
	$database="statmous_analysis";	
	$db = new PDO('mysql:host=localhost;dbname='.$database.';charset=utf8', $username, $password);
	$db->setAttribute(PDO::ATTR_EMULATE_PREPARES, false);
	$db->setAttribute( PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
	
	//todo sqlinjection protection
	$champion = $_GET['champion'];
	$page = $_GET['pg'];
	if(isset($_GET['numPerPage'])){
		$numPerPage = $_GET['numPerPage'];
	} else {
		$numPerPage = 10;
	}
	
	$query = "SELECT * FROM itempower where championName = :champion order by itemPower desc limit :numPerPage offset :offset";
	?>
	
	<div id="championsbody">
		<p><?php 
		$champion = new Champion($champion); 
		echo "<img style='width:15%;' src='".$champion->GetImagePath()."' />";
		echo "Items For ".$champion->name;
		?></p>
		
		<table>
		<tr><td>Item Name</td><td>Popularity</td><td>Item Power</td></tr>
		<?php
			$stmt = $db->prepare($query);
			$stmt->bindValue(':champion', $champion->name, PDO::PARAM_STR);
			$stmt->bindValue(':numPerPage', $numPerPage, PDO::PARAM_INT);
			$stmt->bindValue(':offset', $page*$numPerPage, PDO::PARAM_INT);
			$stmt->execute();
			$results = $stmt->fetchAll();
			foreach($results as $row) {
	    			echo "<tr><td><img style='height: 50%;' src='/img/item/".$row['itemId'].".png' />".$row['itemName']."</td><td>".$row['popularityPerc']."%</td><td>".$row['itemPower']."</td></tr>";
	    		}
		?>
		</table>
		
		<!---CBJ 12.5.14 Added <p>'s and </br>'s to make page buttons easier to use. should really do this with div blocks or something--->
		<p></p>
		<?php			
	    		//CBJ 12.5.14 Now checks if there are previous or future pages available before presenting page change links
	    		if($page>0) {
	    			echo "<p><a href='champion.php?champion=".htmlentities($champion->name, ENT_QUOTES)."&pg=".($page-1)."' style='color: black;' > Previous Page </a></p>";
	    		} else { 
	    			echo "</br>";
	    		}
	    		if (count($results)==$numPerPage) {
	    			echo "<p><a href='champion.php?champion=".htmlentities($champion->name, ENT_QUOTES)."&pg=".($page+1)."' style='color: black;' > Next Page </a></p>";
	    		} else { 
	    			echo "</br>";
	    		}
	    	?>	
	</div>
		
	<?php 
	$db = null;
	?>
		
<?php include('inc/footer.php'); ?>