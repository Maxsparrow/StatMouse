<?php 
include('inc/header.php');
include('model/champion.php');
 ?>
	
	<?php
	include('connections.php');
	
	$database="statmous_analysis";	
	$db = new PDO('mysql:host=localhost;dbname='.$database.';charset=utf8', $username, $password);
	$db->setAttribute(PDO::ATTR_EMULATE_PREPARES, false);
	$db->setAttribute( PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
	
	//TODO SQLINJECTION PROTECTION
	$page = $_GET['pg'];
	if(isset($_GET['numPerPage'])){
		$numPerPage = $_GET['numPerPage'];
	} else {
		$numPerPage = 10;
	}
	?>
	
	<div id="championsbody">
		<p>Champions</p>
		<table>
		<tr><td>Name</td></tr>
		<?php
			$query = "SELECT DISTINCT(championName) FROM `itempower` order by championName limit :numPerPage offset :offset";
			$stmt = $db->prepare($query);
			$stmt->bindValue(':numPerPage', $numPerPage, PDO::PARAM_INT);
			$stmt->bindValue(':offset', $page*$numPerPage, PDO::PARAM_INT);
			$stmt->execute();
			$results = $stmt->fetchAll();
			
			foreach($results as $row) {
				$champion = new Champion($row['championName']);
				$championurl = "<a href='".$champion->GetChampionPageUrl()."' style='color: black;'>";
	    			echo "<tr><td>".$championurl."<img style='width: 50%;' src='".$champion->GetImagePath()."' /></a></td><td>".$championurl.$row['championName']."</a></td></tr>";
	    		}
		?>
		</table>
		
		<!---CBJ 12.5.14 Added <p>'s and </br>'s to make page buttons easier to use. should really do this with div blocks or something--->
		<p></p>
		<?php			
	    		//CBJ 12.5.14 Now checks if there are previous or future pages available before presenting page change links
	    		if($page>0) {
	    			echo "<p><a href='champions.php?pg=".($page-1)."' style='color: black;' > Previous Page </a></p>";
	    		} else { 
	    			echo "</br>";
	    		}
	    		if (count($results)==$numPerPage) {
	    			echo "<p><a href='champions.php?pg=".($page+1)."' style='color: black;' > Next Page </a></p>";
	    		} else { 
	    			echo "</br>";
	    		}
	    	?>
	</div>
		
	<?php 
	$db = null;
	?>
		
<?php include('inc/footer.php'); ?>