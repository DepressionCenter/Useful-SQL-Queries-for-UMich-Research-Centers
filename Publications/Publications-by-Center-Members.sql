/* Publications by Center Members
 * 
 * Author(s): Gabriel Mongefranco (mongefrg@umich.edu)
 * 
 * Summary:
 * Gets a list of all publications authored by, contributed to, or edited by members of the specified Center or Institute.
 * 
 * Description:
 * Detailed publication data from center members published in the past 5 years.
 *
 * Data Sources:
 * Medical School Data Warehouse - Publications
 * 
 * Remarks:
 * Some commonly-used filters can be found at the bottom. Uncomment and edit them as needed.
 * 
 */
SELECT DISTINCT
	pub.PUBLCTN_ID,
	pub.publctn_ttl,
	pub.PUBLCTN_ABSTRCT_CRP,
	pub.publctn_typ,
	pub.PUBLCTN_DT,
	pub.PUBLCTN_AUTHR_CNT,
	pub.PUBLCTN_AUTHR,
	LISTAGG(DISTINCT pubauthors.USR_USERNAME, ',') WITHIN GROUP (
		ORDER BY pubauthors.USR_USERNAME) OVER(PARTITION BY pub.PUBLCTN_ID) AS AUTHOR_UNIQNAMES,
	LISTAGG(DISTINCT pubcontributors.USR_USERNAME, ',') WITHIN GROUP (
		ORDER BY pubcontributors.USR_USERNAME) OVER(PARTITION BY pub.PUBLCTN_ID) AS CONTRIBUTOR_UNIQNAMES,
	pub.publctn_editor,
	LISTAGG(DISTINCT pubeditors.USR_USERNAME, ',') WITHIN GROUP (
		ORDER BY pubeditors.USR_USERNAME) OVER(PARTITION BY pub.PUBLCTN_ID) AS EDITOR_UNIQNAMES,
	pub.PUBLCTN_KEYWORD,
	pub.publctn_lang,
	pub.publctn_pub_url,
	pub.publctn_loc,
	pub.publctn_stat,
	pub.PUBLCTN_DOI,
	pub.PUBLCTN_EXTRNL_ID,
	pub.publctn_jrnl,
	pub.PUBLCTN_CANONICAL_JRNL_TTL,
	pub.publctn_prnt_ttl,
	pub.publctn_conference_nm,
	pub.PUBLCTN_SERIES,
	pub.PUBLCTN_ISSUE,
	pub.publctn_keyword,
	(CASE
		WHEN pub.PUBLCTN_ISBN_13 IS NULL THEN pub.PUBLCTN_ISBN_10
		ELSE pub.PUBLCTN_ISBN_13
	END) AS PUBLCTN_ISBN,
	pub.PUBLCTN_CIT_CNT,
	pub.publctn_rltv_cit_ratio,
	pub.publctn_load_dt,
	pub.PUBLCTN_COMMISIONING_BODY,
	pub.publctn_data_src,
	pub.publctn_funding_acknwldg,
	pub.publctn_funding_acknwldg_txt,
	pub.publctn_patent_stat
FROM
	-- Publications main table
	PUBLICATIONS.PUBLCTN pub
	-- Required link to authors (ignore bad data, like publications without an author)
	INNER JOIN PUBLICATIONS.PUR pubauthorlink ON
		pub.PUBLCTN_ID = pubauthorlink.PUR_PUBLCTN_ID
		AND pubauthorlink.PUR_TYP = 'Authored by'
		AND pubauthorlink.PUR_PRVCY_LVL = 'Public' -- Respect this privacy setting
	LEFT OUTER JOIN PUBLICATIONS.USR pubauthors ON
		pubauthorlink.PUR_USR_ID = pubauthors.USR_ID_USR_ID
	-- Optional link to contributors
	-- Not all contributors might be UMich faculty/staff, and will not have a uniqname
	LEFT OUTER JOIN PUBLICATIONS.PUR pubcontriborlink ON
		pub.PUBLCTN_ID = pubcontriborlink.PUR_PUBLCTN_ID
		AND pubcontriborlink.PUR_TYP = 'Contributed to by'
		AND pubcontriborlink.PUR_PRVCY_LVL = 'Public' -- Respect this privacy setting
	LEFT OUTER JOIN PUBLICATIONS.USR pubcontributors ON
		pubcontriborlink.PUR_USR_ID = pubcontributors.USR_ID_USR_ID
	-- Optional link to editors
	-- Not all editors might be UMich faculty/staff, and will not have a uniqname
	LEFT OUTER JOIN PUBLICATIONS.PUR pubeditorlink ON
		pub.PUBLCTN_ID = pubeditorlink.PUR_PUBLCTN_ID
		AND pubeditorlink.PUR_TYP = 'Edited by'
		AND pubeditorlink.PUR_PRVCY_LVL = 'Public' -- Respect this privacy setting
	LEFT OUTER JOIN PUBLICATIONS.USR pubeditors ON
		pubeditorlink.PUR_USR_ID = pubeditors.USR_ID_USR_ID
WHERE
	1 = 1
	-- Only published (exclude submitted, pending, null, etc.)
	AND pub.PUBLCTN_STAT IN ('Published', 'Published online')
	-- Only if published on the past 5 years (including current year)
	-- There could be bad data with publication years in the future, but this will exclude those
	AND ( EXTRACT(YEAR FROM pub.PUBLCTN_DT) BETWEEN EXTRACT(YEAR FROM SYSDATE)-4 AND EXTRACT(YEAR FROM SYSDATE) )
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

	/* Example Filters */
	
	-- Keyword or topic search for Mental Health related publications
	-- This uses Oracle Text to facilitate searching through large text fields
	-- about(topic) returns entries on the topic specified
	-- Each keyword or key phrase should be grouped in parenthesis
	/*AND (
			CONTAINS(pub.PUBLCTN_TTL, 'about(Mental Health) OR (Mental Health) OR (Depression) OR (bipolar disorder) OR (bipolar depression) OR (schizophrenia)') > 0
			OR CONTAINS(pub.PUBLCTN_ABSTRCT_CRP, 'about(Mental Health) OR (Mental Health) OR (Depression) OR (bipolar disorder) OR (bipolar depression) OR (schizophrenia)') > 0
			OR CONTAINS(pub.PUBLCTN_ABSTRCT, 'about(Mental Health) OR (Mental Health) OR (Depression) OR (bipolar disorder) OR (bipolar depression) OR (schizophrenia)') > 0
			OR CONTAINS(pub.PUBLCTN_KEYWORD, '(Mental Health) OR (Depression) OR (bipolar disorder) OR (bipolar depression) OR (schizophrenia)') > 0
	)*/
	
	-- Only publications that have a funding acknowledgement or commissioning body, 
	-- or that contain funding-related keywords
	/*AND (
			pub.PUBLCTN_FUNDING_ACKNWLDG IS NOT NULL
			OR CONTAINS(pub.PUBLCTN_TTL, '(Funding) OR (Sponsor) OR (Sponsorship) OR (Sponsored) OR (Grant) OR (Foundation) OR (Trust)') > 0
			OR CONTAINS(pub.PUBLCTN_ABSTRCT_CRP, '(Funding) OR (Sponsor) OR (Sponsorship) OR (Sponsored) OR (Grant) OR (Foundation) OR (Trust)') > 0
			OR CONTAINS(pub.PUBLCTN_ABSTRCT, '(Funding) OR (Sponsor) OR (Sponsorship) OR (Sponsored) OR (Grant) OR (Foundation) OR (Trust)') > 0
			OR CONTAINS(pub.PUBLCTN_KEYWORD, '(Funding) OR (Sponsor) OR (Sponsorship) OR (Sponsored) OR (Grant) OR (Foundation) OR (Trust)') > 0
	)*/

	-- Only publications that were added to Michigan Research Experts (Dimensions software) since last week
	-- AND TRUNC(pub.PUBLCTN_LOAD_DT) >= TRUNC(SYSDATE)-7
		
	
	
