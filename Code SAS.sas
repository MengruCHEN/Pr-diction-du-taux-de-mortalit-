/************************************************************************/
/* Programme : Prédiction des taux de mortalité par région avec SAS     */
/* Auteur    : Mengru CHEN, Chuyao LU, Sina MBAYE, Edimah SONGO         */
/* Date      : 20/12/2021                                               */
/************************************************************************/


/********************************************************/
/*          1-Import des données                                                                                    */
/********************************************************/

/* Fixation d'un chemin du fichier pour faciliter l'accès pour les autres utilisateurs */
%let path=/home/u59835570/Projet SAS 2021;

FILENAME REFFILE "&path./cancer_reg.csv";
PROC IMPORT DATAFILE	=	REFFILE
			DBMS		=	CSV
			OUT			=	CANCER_DATA;
			GETNAMES	=	YES;
RUN;
* 3047 observations et 34 variables;


/********************************************************/
/*          2-Audit des données                                                                                      */
/********************************************************/

/* Voir la structure générale des variables */
PROC CONTENTS DATA = CANCER_DATA order = varnum; RUN;
* La plupart des variables sont numériques 
  sauf de binnedInc qui est un intervalle et geography;

/* Je vérifie l'absence de doublons */
PROC SORT DATA = CANCER_DATA nodupkey out = temp dupout = doublons; By Geography; RUN; 
* Aucun doublon : une ligne de résultat par lieu;
* La clé primaire est Geography;

/* Créer une variable Region qui facilitera l'analyse par la suite */
DATA CANCER_DATA2;
	SET CANCER_DATA;                    
	Region = substr(Geography,index(Geography,',')+2);  
RUN;

/* Observation des variables qualitatives */
PROC FREQ DATA = CANCER_DATA2 order = freq; TABLE binnedInc Region; RUN;
* Il y a des régions qui possèdent qu'un seul county : problème;

/* Correction de pb de nom de région */
DATA CANCER_DATA3;
SET CANCER_DATA2;
	IF Region = "North Carolin" THEN Region = "North Carolina";
	IF Region = "North Caroli"  THEN Region = "North Carolina";
	IF Region = "South Carolin" THEN Region = "South Carolina";
	IF Region = "South Caroli"  THEN Region = "South Carolina";
	IF Region = ""				THEN Region = "Alaska";
	IF Region = "Alask"			THEN Region = "Alaska";
	IF Region = "Ala"			THEN Region = "Alaska";
	IF Region = "Californi"		THEN Region = "California";
	IF Region = "Minneso"		THEN Region = "Minnesota";
	IF Region = "Mississip"		THEN Region = "Mississippi";
	IF Region = "Pennsylvan"	THEN Region = "Pennsylvania";
	IF Region = "New Hampshir"	THEN Region = "New Hampshire";
	IF Region = "North Dakot"	THEN Region = "North Dakota";
	IF Region = "Louisian"		THEN Region = "Louisiana";
	IF Region = "Loui"			THEN Region = "Louisiana";
	IF Region = "District of"	THEN DELETE;
RUN;

PROC FREQ DATA = CANCER_DATA3 NLEVELS ORDER = freq ; TABLE Region; RUN;
* Il y a bien maintenant 50 états;

/* Observation des variables quantitatives */
PROC MEANS DATA = CANCER_DATA3 N NMISS MIN Q1 MEDIAN MEAN Q3 MAX;
VAR TARGET_deathRate avgAnnCount avgDeathsPerYear incidenceRate 
    medIncome popEst2015 povertyPercent studyPerCap
    MedianAge MedianAgeMale MedianAgeFemale
    AvgHouseholdSize PercentMarried
    PctNoHS18_24 PctHS18_24 PctSomeCol18_24 PctBachDeg18_24 PctHS25_Over PctBachDeg25_Over 
    PctEmployed16_Over PctUnemployed16_Over
    PctPrivateCoverage PctPrivateCoverageAlone PctEmpPrivCoverage PctPublicCoverage PctPublicCoverageAlone 
    PctWhite PctBlack PctAsian PctOtherRace 
    PctMarriedHouseholds BirthRate;
RUN;

* Correction 1 : 
  La variable PctSomeCol18_24 			contient trop de valeur manquante 75%
  -> à supprimer deplus peu intéressante car connait PctBachDeg18_24
  La variable PctEmployed16_Over		contient bcp de valeur manquante   5%
  -> à supprimer car PctUnemployed16_Over fournit des informations similaires |corr|>0.65
  La variable PctPrivateCoverageAlone	contient trop de valeur manquante 19%
  -> à supprimer car PctPrivateCoverage fournit des informations similaires   |corr|>0.93
  -> au passage on peut aussi supprimer PctPublicCoverageAlone                |corr|>0.89;
PROC CORR DATA = CANCER_DATA3 NOMISS PEARSON; VAR PctEmployed16_Over PctUnemployed16_Over; RUN;
PROC CORR DATA = CANCER_DATA3 NOMISS PEARSON; 
	VAR PctPrivateCoverage PctPrivateCoverageAlone PctEmpPrivCoverage 
	PctPublicCoverage PctPublicCoverageAlone ; 
RUN;
DATA CANCER_DATA4 (DROP = PctSomeCol18_24 PctEmployed16_Over PctPrivateCoverageAlone PctPublicCoverageAlone); 
SET CANCER_DATA3; RUN;

* Correction 2 :
  Age médian max est supérieur à 100;
DATA CANCER_DATA5;
SET CANCER_DATA4;
	IF MedianAge > 100 THEN MedianAge = MedianAge/10;
RUN;

* Remarque : la variable studyPerCap contient beaucoup de 0;
DATA CANCER_SPC0; SET CANCER_DATA4 (where=(studyPerCap=0)); RUN;
PROC FREQ DATA = CANCER_SPC0; TABLE Region; RUN;
PROC FREQ DATA = CANCER_DATA5; TABLE Region; RUN;
PROC CORR DATA = CANCER_DATA5 NOMISS PEARSON; VAR studyPerCap povertyPercent medIncome; RUN;
TITLE "Pauvreté vs nombre d’essais cliniques";
PROC SGPLOT DATA = CANCER_DATA4;
	SCATTER X = studyPerCap Y = povertyPercent;
	XAXIS GRID;
	YAXIS GRID;
RUN;
* On pensait que le lien était fort entre pauvreté/revenu et le nombre d'essaie clinique
  En comparant on voit que les régions qui font le moins de test clinique
  ne sont pas forcément les plus pauvres;


/********************************************************/
/*	3-Représentations graphiques 						*/
/********************************************************/

/* Observation de la variable à prédire*/
TITLE 'Distribution de la mortalité moyenne par habitant par région';
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM TARGET_deathRate;
	DENSITY TARGET_deathRate / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY TARGET_deathRate / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;
* Les deux courbes se ressemblent bcp et peu d'asymétrie
  la variable d'intérêt suit une loi normale;

/* Observation variable explicatives quantitatives */
TITLE 'Distribution du nombre moyen de cas déclarés de cancer diagnostiqués chaque année';
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM avgAnnCount;
	DENSITY avgAnnCount / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY avgAnnCount / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;

TITLE 'Distribution du nombre moyen de décès signalés dus au cancer';
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM avgDeathsPerYear;
	DENSITY avgDeathsPerYear / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY avgDeathsPerYear / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;

TITLE 'Distribution de la population par région';
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM popEst2015;
	DENSITY popEst2015 / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY popEst2015 / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;

TITLE 'Distribution du revenu médian par région';
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM medIncome;
	DENSITY medIncome / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY medIncome / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;
* Le revenu suit une loi gaussienne;

TITLE 'Distribution du nombre d’essais cliniques liés au cancer par région';
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM studyPerCap;
	DENSITY studyPerCap / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY studyPerCap / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;

TITLE 'Pourcentage de la population vivant dans la pauvreté par région';
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM povertyPercent;
	DENSITY povertyPercent / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY povertyPercent / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;
* Une asymétrie à droite;

TITLE "Distribution de l'âge médian des habitants par région";
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM MedianAge;
	DENSITY MedianAge / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY MedianAge / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;

TITLE "Pourcentage d'habitants de la région âgés de 16 ans ou plus et ayant un emploi ";
PROC SGPLOT DATA = CANCER_DATA3;
	HISTOGRAM PctEmployed16_Over;
	DENSITY PctEmployed16_Over / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY PctEmployed16_Over / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;

TITLE "Pourcentage d’habitants de la région avec un Bac+3 ";
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM PctBachDeg18_24;
	DENSITY PctBachDeg18_24 / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY PctBachDeg18_24 / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;
* Asymétrie à droite;

TITLE "Pourcentage d'habitants de la région bénéficiant d'une couverture médicale privée ";
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM PctPrivateCoverage;
	DENSITY PctPrivateCoverage / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY PctPrivateCoverage / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;

TITLE "Pourcentage d'habitants de la région bénéficiant d'une couverture médicale fournie par l'entreprise";
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM PctEmpPrivCoverage;
	DENSITY PctEmpPrivCoverage / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY PctEmpPrivCoverage / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;

TITLE "Pourcentage d'habitants de la région bénéficiant d'une couverture médicale fournie par le gouvernement";
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM PctPublicCoverage;
	DENSITY PctPublicCoverage / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY PctPublicCoverage / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;

TITLE "Pourcentage du nombre de naissances par rapport aux nombre de femmes dans la région";
PROC SGPLOT DATA = CANCER_DATA5;
	HISTOGRAM BirthRate;
	DENSITY BirthRate / TYPE = NORMAL LEGENDLABEL = 'NORMAL' LINEATTRS = (PATTERN = SOLID);
	DENSITY BirthRate / TYPE = KERNEL LEGENDLABEL = 'KERNEL' LINEATTRS = (PATTERN = SOLID);
	KEYLEGEND / LOCATION = INSIDE POSITION = TOPRIGHT ACROSS = 1;
  	XAXIS DISPLAY = (NOLABEL);
RUN;

/* A partir de batchgeo, observation de zones où il y a plus ou moins de décès lié au cancer
https://fr.batchgeo.com/map;


/********************************************************/
/*	4- Création des bases d'apprentissage et de test 	*/
/********************************************************/

PROC SURVEYSELECT DATA = CANCER_DATA5
                  OUTALL		
				  SAMPRATE = 70 	
                  OUT = CANCER_DATA6 (DROP = SELECTIONPROB SAMPLINGWEIGHT)
                  METHOD = SRS /* Simple Random Sample */
                  SEED = 2022; /* Graîne permettant d'obtenir tjs le même échantillon */;				
RUN;
* On prend 70% des données pour l'apprentissage et 30% pour le test;

PROC MEANS Data = CANCER_DATA6 min q1 median mean Q3 max;
Class selected;
VAR TARGET_deathRate;
RUN;
* La distribution de la mortalité moyenne est similaire aux 2 tables;

DATA APPRENTISSAGE TEST;  
SET CANCER_DATA6;
	IF SELECTED = 1 THEN OUTPUT APPRENTISSAGE;
	ELSE OUTPUT TEST;
RUN;
*WORK.APPRENTISSAGE has 2133;
*WORK.TEST has 913;


/********************************************************/
/*	5- Analyse bi-variée							 	*/
/********************************************************/

/* Analyse des variables qualitatives */
PROC ANOVA DATA = APPRENTISSAGE;
	CLASS binnedInc;
	MODEL TARGET_deathRate = binnedInc;
	MEANS binnedInc;
RUN;
QUIT;
* Le taux de mortalité dû au cancer diminue avec le revenue moyen;

PROC ANOVA DATA = APPRENTISSAGE;
	CLASS Region;
	MODEL TARGET_deathRate = Region;
	MEANS Region;
RUN;
QUIT;
* Il est vrai que certain région connait une mortalité beaucoup plus faible que d'autre
  Cela peut être expliqué par les analyses sur les variables qualitatives suivantes;

/* Analyse des variables quantitatives */
TITLE "Taux de mortalité en fonction du revenu";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = medIncome Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction du taux d'incident";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = incidenceRate Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;
* Logique, ça sera peut-être une varianble à retirer;

TITLE "Taux de mortalité en fonction de la pauvreté";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = povertyPercent Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction de l'âge";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = MedianAge Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;
* Bcp de personne meurt de cancer vers 40 ans;

TITLE "Taux de mortalité en fonction de la taille de population";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = popEst2015 Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction du taux de natalité";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = BirthRate Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction du situation familiale";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctMarriedHouseholds Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;
* Tendance à diminuer quand sont en famille
  se soigne car plus de moyen financier ? car par sentiment ? ;

TITLE "Taux de mortalité en fonction du chômage";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctUnemployed16_Over Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;
* Les personnes n'ayant pas de travail ont moins de chance de se faire soigner,
  par conséquent meurent du cancer plus facilement;

/* Analyse des variables quantitatives NIVEAU ETUDES*/
TITLE "Taux de mortalité en fonction du niveau d'étude BAS";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctNoHS18_24 Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction du niveau d'étude MOYEN";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctHS18_24 Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction du niveau d'étude HAUT";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctBachDeg18_24 Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;
*  Une petite tendance de baisse de mortalité quand le niveau d'étude est haut;

/* Analyse des variables quantitatives COUVERTURE DE SANTE */
TITLE "Taux de mortalité en fonction de la couverture de santé PRIVE";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctPrivateCoverage Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction de la couverture de santé ENTREPRISE";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctEmpPrivCoverage Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction de la couverture de santé PUBLIC";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctPublicCoverage Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;
* Ceux ayant une couverture de santé privé/entreprise ont plus de moyen de se faire soigner/rembourser
  les autres ayant droit à l'aide de l'état sont moins remboursés;

TITLE "Couverture de santé PUBLIC vs taux de pauvreté";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctPublicCoverage Y = povertyPercent;
	XAXIS GRID;
	YAXIS GRID;
RUN;
* On remarque que ceux ayant eu besoin de l'aide de l'état sont aussi les régions les plus pauvres;

/* Analyse des variables quantitatives APPARTENANCE ETHNIQUE */
*  Une petite tendance de hausse de mortalité dans les régions 
   où il y a bcp de personne d'identifiant comme noir;
TITLE "Taux de mortalité en fonction de l'appartenance ethnique BLANC";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctWhite Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction de l'appartenance ethnique NOIR";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctBlack Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction de l'appartenance ethnique ASIATIQUE";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctAsian Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

TITLE "Taux de mortalité en fonction de l'appartenance ethnique AUTRE";
PROC SGPLOT DATA = APPRENTISSAGE;
	SCATTER X = PctOtherRace Y = TARGET_deathRate;
	XAXIS GRID;
	YAXIS GRID;
RUN;

/* Coefficient de corrélation */
PROC CORR DATA = CANCER_DATA6 /*NOMISS PEARSON KENDALL SPEARMAN*/;
    VAR TARGET_deathRate avgAnnCount avgDeathsPerYear incidenceRate 
    medIncome popEst2015 povertyPercent studyPerCap
    MedianAge MedianAgeMale MedianAgeFemale
    AvgHouseholdSize PercentMarried
    PctNoHS18_24 PctHS18_24 PctBachDeg18_24 PctHS25_Over PctBachDeg25_Over 
    PctUnemployed16_Over
    PctPrivateCoverage PctEmpPrivCoverage PctPublicCoverage
    PctWhite PctBlack PctAsian PctOtherRace 
    PctMarriedHouseholds BirthRate;
RUN;
* Une corrélation proche de 1 (en valeur absolue) démontre une relation intense;
* les sorties sont le coefficient de corrélation, la p-value et la nb d'observations;
* Remarques à faire :
  - les femmes ont plus de chance de mourir à cause du cancer que les hommes
  - pauvreté, chômage et couverture publique sont des variables corrélées;


/********************************************************/
/*	6- Modélisation            				     	 	*/
/********************************************************/
* Nous allons partir sur une régression linéaire car la variable d'intérêt est continue;

PROC REG DATA = APPRENTISSAGE SIMPLE OUTEST = MODEL;
MODEL TARGET_deathRate =
	avgAnnCount avgDeathsPerYear incidenceRate 
    medIncome popEst2015 povertyPercent studyPerCap
    MedianAge MedianAgeMale MedianAgeFemale
    AvgHouseholdSize PercentMarried
    PctNoHS18_24 PctHS18_24 PctBachDeg18_24 PctHS25_Over PctBachDeg25_Over 
    PctUnemployed16_Over
    PctPrivateCoverage PctEmpPrivCoverage PctPublicCoverage
    PctWhite PctBlack PctAsian PctOtherRace 
    PctMarriedHouseholds BirthRate / SELECTION = STEPWISE SLE = 0.05 SLS = 0.05;
OUTPUT OUT = APPRENTISSAGE_OUT PREDICTED = PRED RESIDUAL = RESIDU
LCL = BORNE_INF UCL = BORNE_SUP 
COOKD = DISTANCE_COOK H = LEVIER;
RUN;
PLOT R.* NQQ.;		  /* Droite d'Henry */
PLOT R. * PREDICTED.; /* Graphe des résidus */
QUIT;

/* Modèle final */
*  après suppression de variables inutiles;
PROC REG DATA = APPRENTISSAGE SIMPLE OUTEST = MODEL;
MODEL TARGET_deathRate = incidenceRate povertyPercent MedianAgeMale PercentMarried
    PctHS18_24 PctHS25_Over PctBachDeg25_Over 
    PctUnemployed16_Over PctPrivateCoverage PctEmpPrivCoverage
    PctOtherRace PctMarriedHouseholds BirthRate / SELECTION = STEPWISE SLE = 0.05 SLS = 0.05;
OUTPUT OUT = APPRENTISSAGE_OUT PREDICTED = PRED RESIDUAL = RESIDU
LCL = BORNE_INF UCL = BORNE_SUP 
COOKD = DISTANCE_COOK H = LEVIER;
RUN;
PLOT R.* NQQ.;		  /* Droite d'Henry */
PLOT R. * PREDICTED.; /* Graphe des résidus */
QUIT;


/********************************************************/
/*	7- Validation            				     	 	*/
/********************************************************/

/* Validation du modèle avec la base de test */
DATA MODEL2;
SET MODEL;
	CLE = 1;
	
	KEEP CLE intercept 
	incidenceRate povertyPercent MedianAgeMale PercentMarried
    PctHS18_24 PctHS25_Over PctBachDeg25_Over 
    PctUnemployed16_Over PctPrivateCoverage PctEmpPrivCoverage
    PctOtherRace PctMarriedHouseholds BirthRate;
    
	RENAME	incidenceRate = B_incidenceRate 
			povertyPercent = B_povertyPercent
			MedianAgeMale = B_MedianAgeMale
			PercentMarried = B_PercentMarried
			PctHS18_24 = B_PctHS18_24
			PctHS25_Over = B_PctHS25_Over
			PctBachDeg25_Over = B_PctBachDeg25_Over
			PctUnemployed16_Over = B_PctUnemployed16_Over
			PctPrivateCoverage = B_PctPrivateCoverage
			PctEmpPrivCoverage = B_PctEmpPrivCoverage
			PctOtherRace = B_PctOtherRace
			PctMarriedHouseholds = B_PctMarriedHouseholds
			BirthRate = B_BirthRate;
RUN;

/* Créer une clé de jointure pour la fusion */
DATA TEST;
SET TEST;
	CLE = 1;
RUN;

/* Fusionner les 2 bases et calculer le Y prédit avec les paramètres des variables */
DATA RESULTATS;
MERGE TEST MODEL2;
By CLE;
Y_pred = intercept + B_incidenceRate*incidenceRate + B_povertyPercent*povertyPercent
	   + B_MedianAgeMale*MedianAgeMale + B_PercentMarried*PercentMarried
	   + B_PctHS18_24*PctHS18_24 + B_PctHS25_Over*PctHS25_Over + B_PctBachDeg25_Over*PctBachDeg25_Over
	   + B_PctUnemployed16_Over*PctUnemployed16_Over
	   + B_PctPrivateCoverage*PctPrivateCoverage + B_PctEmpPrivCoverage*PctEmpPrivCoverage
	   + B_PctOtherRace*PctOtherRace + B_PctMarriedHouseholds*PctMarriedHouseholds 
	   + B_BirthRate*BirthRate;	
residus = TARGET_deathRate - Y_pred;
RUN;

PROC MEANS DATA = RESULTATS; Var residus; RUN;
* Le résidus tend vers 0 en moyenne OK;

PROC GPLOT DATA = RESULTATS;                                                                                                          
   PLOT TARGET_deathRate*Y_pred;                                                             
RUN;                                                                                                                                    
QUIT; 
* Linéarité entre valeur prédite et valeur attendu OK;

PROC GPLOT DATA = RESULTATS;                                                                                                        
   PLOT Y_pred*residus ;                                                             
RUN;                                                                                                                                    
QUIT; 
