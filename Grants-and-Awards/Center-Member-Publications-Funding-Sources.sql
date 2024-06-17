/* Center Member Publications Funding Sources
 * 
 * Author(s): Gabriel Mongefranco (mongefrg@umich.edu)
 * 
 * Summary:
 * Gets funding acknowledgements, and break them up into separate columns for each grant and funding source.
 * 
 * Description:
 * Publications from our center members from the past 5 years, showing only a publication ID and grant info.
 * Filtered by publications that have a funding acknowledgement only.
 * The list of grants has been expanded, with one row per publication, per grant received.
 *
 * Data Sources:
 * Medical School Data Warehouse - Publications
 * 
 * Remarks:
 * Use the FUNDERS column.
 * To make it easier to identify uncommon funding sources, you can also filter on FUNDERS_EXCLUDING_COMMON_SOURCES which excludes NIH, CDC, etc.
 * 
 */
-- Gets funding acknowledgements, and break them up into separate columns for grant and funding source
SELECT DISTINCT
			pub.PUBLCTN_ID,
			REGEXP_SUBSTR(trim(COLUMN_VALUE), '^Grant:\s*([^,]+),', 1, 1, NULL, 1) AS GRANT_CODE,
			(CASE
			WHEN (trim(COLUMN_VALUE) NOT LIKE 'Grant:%'
				AND trim(COLUMN_VALUE) NOT LIKE 'Funder:%')
			THEN
				trim(COLUMN_VALUE)
			ELSE
				REGEXP_SUBSTR(trim(COLUMN_VALUE), 'Funder:\s*([^,]+)', 1, 1, NULL, 1)
			END) AS FUNDERS,
			TRIM(
				REGEXP_REPLACE(
					REGEXP_REPLACE(
						(CASE
							WHEN (trim(COLUMN_VALUE) NOT LIKE 'Grant:%'
								AND trim(COLUMN_VALUE) NOT LIKE 'Funder:%')
							THEN
								' ' || REPLACE(trim(COLUMN_VALUE), ' ', '  ')  || ' '
							ELSE
								' ' || REPLACE(REGEXP_SUBSTR(trim(COLUMN_VALUE), 'Funder:\s*([^,]+)', 1, 1, NULL, 1), ' ', '  ') || ' '
						END),
						'(^|\s)(CDC|NIH|HHS|VA|NHS|NIA|NIDDK|NIMH|National Institute of Health|NIDA|NCATS)(\s|$)',
						' ',
						1,
						0),
					'(\s){2,8}',
					' '
				)
			) AS FUNDERS_EXCLUDING_COMMON_SOURCES
	  from  PUBLICATIONS.PUBLCTN pub,
	  XMLTABLE(('"' || REPLACE(
	  			REPLACE(
	  				REPLACE(REPLACE(pub.publctn_funding_acknwldg, '/', '-'),'"',''''),
	  				'&',
	  				'and'),
	  			';',
	  			'","'
	  		) || '"'))
	  WHERE
			1 = 1
			
			-- Only published (exclude submitted, pending, null, etc.)
			AND pub.PUBLCTN_STAT IN ('Published', 'Published online')
			
			-- Only if published on the past 5 years (including current year)
			AND EXTRACT(YEAR FROM pub.PUBLCTN_DT) BETWEEN EXTRACT(YEAR FROM SYSDATE)-4 AND EXTRACT(YEAR FROM SYSDATE)
			
			-- Only publications that have a funding acknowledgement
			AND pub.PUBLCTN_FUNDING_ACKNWLDG IS NOT NULL
			
			-- Only publications by center members
	  		AND EXISTS(
				SELECT 1
				FROM
					PUBLICATIONS.GRP authg
					INNER JOIN PUBLICATIONS.GRP_USR_MBRSHP authgu
						ON authg.GRP_ID = authgu.GRP_USR_MBRSHP_GRP_ID
					INNER JOIN PUBLICATIONS.PUR pubinvestigatorlink
						ON authgu.GRP_USR_MBRSHP_USR_ID = pubinvestigatorlink.PUR_USR_ID
					WHERE
						authg.GRP_NM = :CenterName --'Eisenberg Family Depresssion Center'
						AND pubinvestigatorlink.PUR_TYP IN ('Authored by', 'Contributed to by', 'Edited by')
						AND pubinvestigatorlink.PUR_PRVCY_LVL = 'Public' -- Respect this privacy setting
						AND pubinvestigatorlink.PUR_PUBLCTN_ID = pub.PUBLCTN_ID
			)
			
