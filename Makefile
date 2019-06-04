# Remove target files after command failure.
.DELETE_ON_ERROR:

models: \
	enwiki_models \
	euwiki_models \
	fawiki_models \
	frwiki_models \
	frwikisource_models \
	glwiki_models \
	ruwiki_models \
	trwiki_models \
	wikidatawiki_models

tuning_reports: \
	enwiki_tuning_reports \
	euwiki_tuning_reports \
	fawiki_tuning_reports \
	frwiki_tuning_reports \
	frwikisource_tuning_reports \
	glwiki_tuning_reports \
	ruwiki_tuning_reports \
	trwiki_tuning_reports \
	wikidatawiki_tuning_reports

wp10_major_minor = 0.8
page_level_major_minor = 0.3
item_quality_major_minor = 0.4

########################## English Wikipedia ###################################
datasets/enwiki.labelings.20150602.json:
	./utility extract_labelings \
	  /mnt/data/xmldatadumps/public/enwiki/20150602/enwiki-20150602-pages-meta-history*.xml*.bz2 \
	  --verbose > $@


datasets/enwiki.labelings.30k.json: \
		datasets/enwiki.labelings.20150602.json
	( \
	  grep -P '"wp10": "stub"' $< | \
	  shuf -n 5000; \
	  grep -P '"wp10": "start"' $< | \
	  shuf -n 5000; \
	  grep -P '"wp10": "c"' $< | \
	  shuf -n 5000; \
	  grep -P '"wp10": "b"' $< | \
	  shuf -n 5000; \
	  grep -P '"wp10": "ga"' $< | \
	  shuf -n 5000; \
	  grep -P '"wp10": "fa"' $< | \
	  shuf -n 5000 \
	) | \
	shuf > $@

datasets/enwiki.labeling_revisions.w_text.30k.json: \
		datasets/enwiki.labelings.30k.json
	cat $< | \
	./utility fetch_text \
	  --api-host=https://en.wikipedia.org  --threads 4 \
	  --verbose > $@

datasets/enwiki.labeling_revisions.w_cache.30k.json: \
		datasets/enwiki.labeling_revisions.w_text.30k.json
	cat $< | \
	./utility extract_from_text \
	  articlequality.feature_lists.enwiki.wp10 \
	  --verbose > $@

datasets/enwiki.labeling_revisions.w_cache.nettrom_30k.json: \
		datasets/enwiki.labeling_revisions.nettrom_30k.json
	cat $< | \
	revscoring extract \
	  articlequality.feature_lists.enwiki.wp10 \
	  --host https://en.wikipedia.org \
	  --verbose > $@

tuning_reports/enwiki.nettrom_wp10.md: \
		datasets/enwiki.labeling_revisions.w_cache.nettrom_30k.json
	cat $< | \
	revscoring tune \
	  config/classifiers.params.yaml \
	  articlequality.feature_lists.enwiki.wp10 \
	  wp10 \
	  accuracy.macro \
	  --pop-rate '"Stub"=0.5762822268640726' \
	  --pop-rate '"Start"=0.322262286213325' \
	  --pop-rate '"C"=0.054466425789533986' \
	  --pop-rate '"B"=0.034532319241616406' \
	  --pop-rate '"GA"=0.009809850215598185' \
	  --pop-rate '"FA"=0.002646891675853838' \
	  --cv-timeout=60 \
	  --debug > $@

models/enwiki.nettrom_wp10.gradient_boosting.model: \
		datasets/enwiki.labeling_revisions.w_cache.nettrom_30k.json
	cat $< | \
	revscoring cv_train \
	  revscoring.scoring.models.GradientBoosting \
	  articlequality.feature_lists.enwiki.wp10 \
	  wp10 \
	  --version $(wp10_major_minor).1 \
	  -p 'n_estimators=500' \
	  -p 'learning_rate=0.01' \
	  -p 'max_features="log2"' \
	  -p 'max_depth=7' \
	  --pop-rate '"Stub"=0.5762822268640726' \
	  --pop-rate '"Start"=0.322262286213325' \
	  --pop-rate '"C"=0.054466425789533986' \
	  --pop-rate '"B"=0.034532319241616406' \
	  --pop-rate '"GA"=0.009809850215598185' \
	  --pop-rate '"FA"=0.002646891675853838' \
	  --center --scale > $@

	revscoring model_info $@ > model_info/enwiki.nettrom_wp10.md

enwiki_models: \
	models/enwiki.nettrom_wp10.gradient_boosting.model

enwiki_tuning_reports: \
	tuning_reports/enwiki.wp10.md \
	tuning_reports/enwiki.nettrom_wp10.md

########################## Basque Wikipedia ####################################


datasets/euwiki.sampled_revisions.172_balanced.json:
	# from https://quarry.wmflabs.org/query/36633
	wget https://quarry.wmflabs.org/run/379904/output/0/json-lines -qO- > $@

datasets/euwiki.human_labeled.400.json:
	./utility fetch_labels \
	 https://labels.wmflabs.org/campaigns/euwiki/79/ > $@

datasets/euwiki.human_labeled.300_balanced.json: \
		datasets/euwiki.human_labeled.400.json
	(cat $< | grep '"wp10": "Stub"' | shuf -n 50; \
	 cat $< | grep '"wp10": "Start"' | shuf -n 50; \
	 cat $< | grep '"wp10": "C"' | shuf -n 50; \
	 cat $< | grep '"wp10": "B"' | shuf -n 50; \
	 cat $< | grep '"wp10": "GA"' | shuf -n 50; \
	 cat $< | grep '"wp10": "FA"' | shuf -n 50) > $@

datasets/euwiki.human_labeled.w_cache.300_balanced.json: \
		datasets/euwiki.human_labeled.300_balanced.json
	cat $< | \
	revscoring extract \
	  articlequality.feature_lists.euwiki.wp10 \
	  --host https://eu.wikipedia.org \
	  --verbose > $@

tuning_reports/euwiki.wp10.md: \
		datasets/euwiki.human_labeled.w_cache.300_balanced.json
	cat $< | \
	revscoring tune \
	  config/classifiers.params.yaml \
	  articlequality.feature_lists.euwiki.wp10 \
	  wp10 \
	  accuracy.macro \
	  --labels '"Stub","Start","C","B","GA","FA"' \
	  --cv-timeout=60 \
	  --debug > $@

models/euwiki.wp10.gradient_boosting.model: \
		datasets/euwiki.human_labeled.w_cache.300_balanced.json
	cat $< | \
	revscoring cv_train \
	  revscoring.scoring.models.GradientBoosting \
	  articlequality.feature_lists.euwiki.wp10 \
	  wp10 \
	  --version $(wp10_major_minor).0 \
	  -p 'n_estimators=300' \
	  -p 'learning_rate=0.01' \
	  -p 'max_features="log2"' \
	  -p 'max_depth=1' \
		--labels '"Stub","Start","C","B","GA","FA"' \
	  --center --scale > $@

	revscoring model_info $@ > model_info/euwiki.wp10.md

euwiki_models: \
	models/euwiki.wp10.gradient_boosting.model

euwiki_tuning_reports: \
	tuning_reports/euwiki.wp10.md

########################## Galician Wikipedia ##################################

datasets/glwiki.ga_and_fa_labeled.233.json:
	wget https://quarry.wmflabs.org/run/290027/output/0/json-lines -qO- > $@

datasets/glwiki.human_labeled.400.json:
	./utility fetch_labels \
		https://labels.wmflabs.org/campaigns/glwiki/85 > $@

datasets/glwiki.merged_labeled.633.json: \
		datasets/glwiki.human_labeled.400.json \
		datasets/glwiki.ga_and_fa_labeled.233.json
	cat $^ > $@

datasets/glwiki.human_labeled.400_balanced.json: \
		datasets/glwiki.merged_labeled.633.json
	(cat $< | grep '"wp10": "Stub"' | shuf -n 67; \
	 cat $< | grep '"wp10": "Start"' | shuf -n 67; \
 	 cat $< | grep '"wp10": "C"' | shuf -n 67; \
 	 cat $< | grep '"wp10": "B"' | shuf -n 67; \
 	 cat $< | grep '"wp10": "GA"' | shuf -n 67; \
 	 cat $< | grep '"wp10": "FA"' | shuf -n 67) > $@

datasets/glwiki.human_labeled.w_cache.400_balanced.json: \
		datasets/glwiki.human_labeled.400_balanced.json
	cat $< | \
	revscoring extract \
	  articlequality.feature_lists.glwiki.wp10 \
	  --host https://gl.wikipedia.org \
	  --verbose > $@

tuning_reports/glwiki.wp10.md: \
		datasets/glwiki.human_labeled.w_cache.400_balanced.json
	cat $< | \
	revscoring tune \
	  config/classifiers.params.yaml \
	  articlequality.feature_lists.glwiki.wp10 \
	  wp10 \
	  accuracy.macro \
	  --labels '"Stub","Start","C","B","GA","FA"' \
	  --cv-timeout=60 \
	  --debug > $@

models/glwiki.wp10.gradient_boosting.model: \
		datasets/glwiki.human_labeled.w_cache.400_balanced.json
	cat $< | \
	revscoring cv_train \
	  revscoring.scoring.models.GradientBoosting \
	  articlequality.feature_lists.glwiki.wp10 \
	  wp10 \
	  --version $(wp10_major_minor).0 \
	  -p 'n_estimators=500' \
	  -p 'learning_rate=0.01' \
	  -p 'max_features="log2"' \
	  -p 'max_depth=3' \
	  --labels '"Stub","Start","C","B","GA","FA"' \
	  --center --scale > $@

	revscoring model_info $@ > model_info/glwiki.wp10.md

glwiki_models: \
	models/glwiki.wp10.gradient_boosting.model

glwiki_tuning_reports: \
	tuning_reports/glwiki.wp10.md


########################## Persian Wikipedia ###################################

# https://quarry.wmflabs.org/query/26452
datasets/fawiki.sampled_revisions.300.json:
	wget https://quarry.wmflabs.org/run/255116/output/0/json-lines?download=true -qO- > $@

datasets/fawiki.human_labeled.100.json:
	./utility fetch_labels \
                https://labels.wmflabs.org/campaigns/fawiki/70/ > $@

datasets/fawiki.human_labeled.300.json:
	./utility fetch_labels \
		https://labels.wmflabs.org/campaigns/fawiki/71/ > $@

datasets/fawiki.human_labeled.600.json:
	./utility fetch_labels \
		https://labels.wmflabs.org/campaigns/fawiki/77/ > $@

datasets/fawiki.labeled_revisions.1k.json: \
		datasets/fawiki.sampled_revisions.300.json \
		datasets/fawiki.human_labeled.600.json \
		datasets/fawiki.human_labeled.300.json \
		datasets/fawiki.human_labeled.100.json
	cat $^ > $@

datasets/fawiki.labeling_revisions.w_text.1k.json: \
		datasets/fawiki.labeled_revisions.1k.json
	cat $< | \
	revscoring fetch_text \
	  --host=https://fa.wikipedia.org \
	  --verbose > $@

datasets/fawiki.labeling_revisions.w_cache.1k.json: \
		datasets/fawiki.labeling_revisions.w_text.1k.json
	cat $< | \
	./utility extract_from_text \
	  articlequality.feature_lists.fawiki.wp10 \
	  --verbose > $@


tuning_reports/fawiki.wp10.md: \
		datasets/fawiki.labeling_revisions.w_cache.1k.json
	grep -v '"wp10": null' $< | \
	revscoring tune \
	  config/classifiers.params.yaml \
	  articlequality.feature_lists.fawiki.wp10 \
	  wp10 \
	  accuracy.macro \
	  --pop-rate '"Stub"=0.18174474959612277' \
	  --pop-rate '"Start"=0.07592891760904685' \
	  --pop-rate '"C"=0.12277867528271405' \
	  --pop-rate '"B"=0.16155088852988692' \
	  --pop-rate '"GA"=0.24232633279483037' \
	  --pop-rate '"FA"=0.21243941841680128' \
	  --center --scale \
	  --cv-timeout=60 \
	  --debug > $@

models/fawiki.wp10.gradient_boosting.model: \
		datasets/fawiki.labeling_revisions.w_cache.1k.json
	grep -v '"wp10": null' $< | \
	revscoring cv_train \
	  revscoring.scoring.models.GradientBoosting \
	  articlequality.feature_lists.fawiki.wp10 \
	  wp10 \
	  --version $(wp10_major_minor).0 \
	  -p 'learning_rate=0.5' \
	  -p 'max_features="log2"' \
	  -p 'n_estimators=100' \
	  -p 'max_depth=7' \
	  --pop-rate '"Stub"=0.18174474959612277' \
	  --pop-rate '"Start"=0.07592891760904685' \
	  --pop-rate '"C"=0.12277867528271405' \
	  --pop-rate '"B"=0.16155088852988692' \
	  --pop-rate '"GA"=0.24232633279483037' \
	  --pop-rate '"FA"=0.21243941841680128' \
	  --center --scale > $@

	revscoring model_info $@ > model_info/fawiki.wp10.md

fawiki_models: \
	models/fawiki.wp10.gradient_boosting.model

fawiki_tuning_reports: \
	tuning_reports/fawiki.wp10.md

########################## French Wikipedia ###################################
#datasets/frwiki.observations.first_labelings.20150602.json:
#	./utility extract_labelings \
#		/mnt/data/xmldatadumps/public/frwiki/20150602/frwiki-20150602-pages-meta-history*.xml*.bz2 > $@

#datasets/frwiki.labelings.20151202.json:
#	./utility extract_labelings \
#	  /mnt/data/xmldatadumps/public/frwiki/20151202/frwiki-20151202-pages-meta-history*.xml*.bz2 > $@

datasets/frwiki.labelings.20181201.json:
	./utility extract_labelings \
	  /mnt/data/xmldatadumps/public/frwiki/20181201/frwiki-20181201-pages-meta-history*.xml*.bz2 > $@


datasets/frwiki.labelings.9k.json: \
		datasets/frwiki.labelings.20181201.json
	( \
	  grep -P '"wp10": "e"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "bd"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "b"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "a"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "ba"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "adq"' $< | \
	  shuf -n 1500 \
	) | \
	shuf > $@

datasets/frwiki.labeling_revisions.w_text.9k.json: \
		datasets/frwiki.labelings.9k.json
	cat $< | \
	./utility fetch_text \
	  --api-host=https://fr.wikipedia.org \
	  --verbose > $@

datasets/frwiki.labeling_revisions.w_cache.9k.json: \
		datasets/frwiki.labeling_revisions.w_text.9k.json
	cat $< | \
	./utility extract_from_text \
	  articlequality.feature_lists.frwiki.wp10 \
	  --verbose > $@


tuning_reports/frwiki.wp10.md: \
		datasets/frwiki.labeling_revisions.w_cache.9k.json
	cat $< | \
	revscoring tune \
	  config/classifiers.params.yaml \
	  articlequality.feature_lists.frwiki.wp10 \
	  wp10 \
	  accuracy.macro \
	  --pop-rate '"e"=0.7314705724717468' \
	  --pop-rate '"bd"=0.2314879676843963' \
	  --pop-rate '"b"=0.03023005873940185' \
	  --pop-rate '"a"=0.0029374402333403227' \
	  --pop-rate '"ba"=0.002439090897978488' \
	  --pop-rate '"adq"=0.00143486997313615' \
	  --center --scale \
	  --cv-timeout=60 \
	  --debug > $@

models/frwiki.wp10.gradient_boosting.model: \
		datasets/frwiki.labeling_revisions.w_cache.9k.json
	cat $< | \
	revscoring cv_train \
	  revscoring.scoring.models.GradientBoosting \
	  articlequality.feature_lists.frwiki.wp10 \
	  wp10 \
	  --version $(wp10_major_minor).0 \
	  -p 'learning_rate=0.01' \
	  -p 'max_features="log2"' \
	  -p 'n_estimators=100' \
	  -p 'max_depth=7' \
	  --pop-rate '"e"=0.7314705724717468' \
	  --pop-rate '"bd"=0.2314879676843963' \
	  --pop-rate '"b"=0.03023005873940185' \
	  --pop-rate '"a"=0.0029374402333403227' \
	  --pop-rate '"ba"=0.002439090897978488' \
	  --pop-rate '"adq"=0.00143486997313615' \
	  --center --scale > $@

	revscoring model_info $@ > model_info/frwiki.wp10.md

frwiki_models: \
	models/frwiki.wp10.gradient_boosting.model

frwiki_tuning_reports: \
	tuning_reports/frwiki.wp10.md

############################# French Wikisource ###############################

# TODO: Use: https://fr.wikisource.org/w/api.php?action=query&prop=revisions&revids=6515962&rvprop=content&rvcontentformat=application/json&formatversion=2

# https://quarry.wmflabs.org/query/18839
datasets/frwikisource.sampled_revisions.200k_2017.json:
	wget https://quarry.wmflabs.org/run/178341/output/0/json-lines?download=true -qO- > $@

datasets/frwikisource.sampled_revisions.with_text.200k_2017.json: \
		datasets/frwikisource.sampled_revisions.200k_2017.json
	cat $< | \
	revscoring fetch_text \
		--host=https://fr.wikisource.org --threads 4 \
		--verbose > $@

datasets/frwikisource.labeled_revisions.with_text.20k_balanced_2017.json: \
		datasets/frwikisource.sampled_revisions.with_text.200k_2017.json
	( \
	  cat $< | \
	  grep 'level=\\"4\\"' | shuf -n 5000 | sed -r 's/"rev_id"/"page_level": "validated", "rev_id"/'; \
          cat $< | \
          grep 'level=\\"3\\"' | shuf -n 5000 | sed -r 's/"rev_id"/"page_level": "proofread", "rev_id"/'; \
          cat $< | \
          grep 'level=\\"1\\"' | shuf -n 5000 | sed -r 's/"rev_id"/"page_level": "not_proofread", "rev_id"/'; \
          cat $< | \
          grep 'level=\\"0\\"' | shuf -n 5000 | sed -r 's/"rev_id"/"page_level": "without_text", "rev_id"/' \
	) > $@

datasets/frwikisource.labeled_revisions.w_cache.20k_balanced_2017.json: \
		datasets/frwikisource.labeled_revisions.with_text.20k_balanced_2017.json
	cat $< | \
	./utility extract_from_text \
	  articlequality.feature_lists.frwikisource.pagelevel \
	  --verbose > $@

tuning_reports/frwikisource.page_level.md: \
		datasets/frwikisource.labeled_revisions.w_cache.20k_balanced_2017.json
	cat $< | \
	revscoring tune \
	  config/classifiers.params.yaml \
	  articlequality.feature_lists.frwikisource.pagelevel \
	  page_level \
	  accuracy.macro \
	  --pop-rate '"validated"=0.17270922526244023' \
	  --pop-rate '"proofread"=0.499288127776051' \
	  --pop-rate '"not_proofread"=0.2962992670724004' \
	  --pop-rate '"without_text"=0.03170337988910835' \
	  --center --scale \
	  --cv-timeout=60 \
	  --debug > $@

models/frwikisource.page_level.gradient_boosting.model: \
		datasets/frwikisource.labeled_revisions.w_cache.20k_balanced_2017.json
	cat $< | \
	revscoring cv_train \
	  revscoring.scoring.models.GradientBoosting \
	  articlequality.feature_lists.frwikisource.pagelevel \
	  page_level \
	  --version $(page_level_major_minor).0 \
	  -p 'n_estimators=700' \
	  -p 'learning_rate=0.01' \
	  -p 'max_features="log2"' \
	  -p 'max_depth=7' \
	  --pop-rate '"validated"=0.17270922526244023' \
	  --pop-rate '"not_proofread"=0.499288127776051' \
	  --pop-rate '"proofread"=0.2962992670724004' \
	  --pop-rate '"without_text"=0.03170337988910835' \
	  --center --scale > $@

	revscoring model_info $@ > model_info/frwikisource.page_level.md

frwikisource_models: \
	models/frwikisource.page_level.gradient_boosting.model

frwikisource_tuning_reports: \
	tuning_reports/frwikisource.page_level.md

########################## Russian Wikipedia ###################################
datasets/ruwiki.labelings.20181201.json:
	./utility extract_labelings \
		/mnt/data/xmldatadumps/public/ruwiki/20181201/ruwiki-20181201-pages-meta-history*.xml*.bz2 > $@

datasets/ruwiki.labelings.10k.json: \
	datasets/ruwiki.labelings.20181201.json
	( \
	  grep -P '"wp10": "I"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "II"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "III"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "IV"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "\\u0425\\u0421"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "\\u0414\\u0421"' $< | \
	  shuf -n 1500; \
	  grep -P '"wp10": "\\u0418\\u0421"' $< | \
	  shuf -n 1500 \
	) | \
	shuf > $@

datasets/ruwiki.labeling_revisions.w_text.10k.json: \
		datasets/ruwiki.labelings.10k.json
	cat $< | \
	./utility fetch_text \
	  --api-host=https://ru.wikipedia.org \
	  --verbose > $@

datasets/ruwiki.labeling_revisions.w_cache.10k.json: \
		datasets/ruwiki.labeling_revisions.w_text.10k.json
	cat $< | \
	./utility extract_from_text \
	  articlequality.feature_lists.ruwiki.wp10 \
	  --verbose > $@

tuning_reports/ruwiki.wp10.md: \
		datasets/ruwiki.labeling_revisions.w_cache.10k.json
	cat $< | \
	revscoring tune \
	  config/classifiers.params.yaml \
	  articlequality.feature_lists.ruwiki.wp10 \
	  wp10 \
	  accuracy.macro \
	  --pop-rate '"IV"=0.4872864906832298' \
	  --pop-rate '"III"=0.3625905797101449' \
	  --pop-rate '"II"=0.09298007246376812' \
	  --pop-rate '"I"=0.02902432712215321' \
	  --pop-rate '"ХС"=0.011380693581780538' \
	  --pop-rate '"ДС"=0.009265010351966873' \
	  --pop-rate '"ИС"=0.007472826086956522' \
	  --center --scale \
	  --cv-timeout=60 \
	  --debug > $@

models/ruwiki.wp10.gradient_boosting.model: \
		datasets/ruwiki.labeling_revisions.w_cache.10k.json
	cat $< | \
	revscoring cv_train \
	  revscoring.scoring.models.GradientBoosting \
	  articlequality.feature_lists.ruwiki.wp10 \
	  wp10 \
	  --version $(wp10_major_minor).0 \
	  -p 'max_depth=5' \
	  -p 'learning_rate=0.01' \
	  -p 'max_features="log2"' \
	  -p 'n_estimators=300' \
	  --pop-rate '"IV"=0.4872864906832298' \
	  --pop-rate '"III"=0.3625905797101449' \
	  --pop-rate '"II"=0.09298007246376812' \
	  --pop-rate '"I"=0.02902432712215321' \
	  --pop-rate '"ХС"=0.011380693581780538' \
	  --pop-rate '"ДС"=0.009265010351966873' \
	  --pop-rate '"ИС"=0.007472826086956522' \
	  --center --scale > $@

	revscoring model_info $@ > model_info/ruwiki.wp10.md

ruwiki_models: \
	models/ruwiki.wp10.gradient_boosting.model

riwiki_tuning_reports: \
	tuning_reports/ruwiki.wp10.md


########################## Swedish Wikipedia ###################################
datasets/svwiki.labelings.20190301.json: \
		/mnt/data/xmldatadumps/public/svwiki/20190301/svwiki-20190301-pages-meta-history.xml.bz2
	./utility extract_labelings $< > $@

datasets/svwiki.labelings.2k.json: \
		datasets/svwiki.labelings.20190301.json
	(cat $< | grep '"wp10": "u"' | shuf -n 500; \
	 cat $< | grep '"wp10": "b"' | shuf -n 500; \
	 cat $< | grep '"wp10": "r"' | shuf -n 500; \
	 cat $< | grep '"wp10": "s"' | shuf -n 500) > $@

datasets/svwiki.labeling_revisions.w_text.2k.json: \
		datasets/svwiki.labelings.2k.json
	cat $< | \
	./utility fetch_text \
	  --api-host=https://sv.wikipedia.org \
	  --verbose > $@

datasets/svwiki.labeling_revisions.w_cache.2k.json: \
		datasets/svwiki.labeling_revisions.w_text.2k.json
	cat $< | \
	./utility extract_from_text \
	  articlequality.feature_lists.svwiki.wp10 \
	  --verbose > $@

tuning_reports/svwiki.wp10.md: \
		datasets/svwiki.labeling_revisions.w_cache.2k.json
	cat $< | \
	revscoring tune \
	  config/classifiers.params.yaml \
	  articlequality.feature_lists.svwiki.wp10 \
	  wp10 \
	  roc_auc.macro \
	  --pop-rate '"u"=0.019' \
	  --pop-rate '"b"=0.060' \
	  --pop-rate '"r"=0.042' \
	  --pop-rate '"s"=0.879' \
	  --center --scale \
	  --cv-timeout=60 \
	  --debug > $@

models/svwiki.wp10.gradient_boosting.model: \
		datasets/svwiki.labeling_revisions.w_cache.2k.json
	cat $< | \
	revscoring cv_train \
	  revscoring.scoring.models.GradientBoosting \
	  articlequality.feature_lists.svwiki.wp10 \
	  wp10 \
	  --version $(wp10_major_minor).0 \
	  -p 'learning_rate=0.01' \
	  -p 'max_features="log2"' \
	  -p 'n_estimators=500' \
	  -p 'max_depth=3' \
	  --pop-rate '"u"=0.019' \
	  --pop-rate '"b"=0.060' \
	  --pop-rate '"r"=0.042' \
	  --pop-rate '"s"=0.879' \
	  --center --scale > $@

	revscoring model_info $@ > model_info/svwiki.wp10.md

svwiki_models: \
	models/svwiki.wp10.gradient_boosting.model

svwiki_tuning_reports: \
	tuning_reports/svwiki.wp10.md


############################ Turkish Wikipedia #############################
datasets/trwiki.labelings.20181201.json:
	./utility extract_labelings \
		/mnt/data/xmldatadumps/public/trwiki/20181201/trwiki-20181201-pages-meta-history.xml.bz2 > $@

datasets/trwiki.labelings.2k.json: \
		datasets/trwiki.labelings.20181201.json
	(cat $< | grep '"wp10": "taslak"' | shuf -n 272; \
	 cat $< | grep '"wp10": "baslag\\u0131\\u00e7"' | shuf -n 272; \
	 cat $< | grep '"wp10": "c"' | shuf -n 272; \
	 cat $< | grep '"wp10": "b"' | shuf -n 272; \
	 cat $< | grep '"wp10": "km"' | shuf -n 272; \
	 cat $< | grep '"wp10": "sm"' | shuf -n 272) > $@

datasets/trwiki.labeling_revisions.w_text.2k.json: \
		datasets/trwiki.labelings.2k.json
	cat $< | \
	./utility fetch_text \
	  --api-host=https://tr.wikipedia.org \
	  --verbose > $@

datasets/trwiki.labeling_revisions.w_cache.2k.json: \
		datasets/trwiki.labeling_revisions.w_text.2k.json
	cat $< | \
	./utility extract_from_text \
	  articlequality.feature_lists.trwiki.wp10 \
	  --verbose > $@

tuning_reports/trwiki.wp10.md: \
		datasets/trwiki.labeling_revisions.w_cache.2k.json
	cat $< | \
	revscoring tune \
	  config/classifiers.params.yaml \
	  articlequality.feature_lists.trwiki.wp10 \
	  wp10 \
	  accuracy.macro \
	  --pop-rate '"taslak"=0.5804005556841861' \
	  --pop-rate '"baslagıç"=0.24774253299374854' \
	  --pop-rate '"c"=0.08595739754572818' \
	  --pop-rate '"b"=0.05319518407038666' \
	  --pop-rate '"km"=0.016959944431581383' \
	  --pop-rate '"sm"=0.015744385274369065' \
	  --center --scale \
	  --cv-timeout=60 \
	  --debug > $@

models/trwiki.wp10.gradient_boosting.model: \
		datasets/trwiki.labeling_revisions.w_cache.2k.json
	cat $< | \
	revscoring cv_train \
	  revscoring.scoring.models.GradientBoosting \
	  articlequality.feature_lists.trwiki.wp10 \
	  wp10 \
	  --version $(wp10_major_minor).0 \
	  -p 'max_depth=5' \
	  -p 'learning_rate=0.01' \
	  -p 'max_features="log2"' \
	  -p 'n_estimators=300' \
	  --pop-rate '"taslak"=0.5804005556841861' \
	  --pop-rate '"baslagıç"=0.24774253299374854' \
	  --pop-rate '"c"=0.08595739754572818' \
	  --pop-rate '"b"=0.05319518407038666' \
	  --pop-rate '"km"=0.016959944431581383' \
	  --pop-rate '"sm"=0.015744385274369065' \
	  --center --scale > $@

	revscoring model_info $@ > model_info/trwiki.wp10.md

trwiki_models: \
	models/trwiki.wp10.gradient_boosting.model

trwiki_tuning_reports: \
	tuning_reports/trwiki.wp10.md

############################# Wikidata ######################################

# From https://quarry.wmflabs.org/query/17904
datasets/wikidatawiki.stratified_revisions.filtered_sample.json:
	wget https://quarry.wmflabs.org/run/167696/output/0/json-lines?download=true -qO- | \
	./utility fetch_item_info --api-host https://wikidata.org --claim P31 --verbose | \
	grep -v '"P31": "Q4167410"' | \
	grep -v '"P31": "Q4167836"' | \
	grep -v '"P31": "Q17633526"' | \
	grep -v '"P31": "Q11266439"' | \
	grep -v '"P31": "Q13406463"' > $@


datasets/wikidatawiki.stratified_revisions.5k_sample.json: \
		datasets/wikidatawiki.stratified_revisions.filtered_sample.json
	( \
	  cat $< | \
	  grep '"strata": "1024"' | shuf -n 1000; \
	  cat $< | \
	  grep '"strata": "8192"' | shuf -n 1000; \
	  cat $< | \
	  grep '"strata": "131072"' | shuf -n 1000; \
	  cat $< | \
	  grep '"strata": "262144"' | shuf -n 250; \
	  cat $< | \
	  grep '"strata": "inf"' | shuf -n 250; \
	  cat $< | \
	  grep '"strata": "low-qid"' | shuf -n 1500 \
	) > $@

datasets/wikidatawiki.labelings.5k.json:
	./utility fetch_labels \
		https://labels.wmflabs.org/campaigns/wikidatawiki/53/ > $@

datasets/wikidatawiki.labeling_revisions.w_cache.5k.json: \
		datasets/wikidatawiki.labelings.5k.json
	cat $< | \
	revscoring extract \
	  articlequality.feature_lists.wikidatawiki.item_quality \
	  --host https://www.wikidata.org \
	  --batch-size 10 \
	  --verbose > $@

tuning_reports/wikidatawiki.item_quality.md: \
		datasets/wikidatawiki.labeling_revisions.w_cache.5k.json
	cat $< | \
	revscoring tune \
	  config/classifiers.params.yaml \
	  articlequality.feature_lists.wikidatawiki.item_quality \
	  item_quality \
	  accuracy.macro \
	  --labels '"A","B","C","D","E"' \
	  --cv-timeout=60 \
	  --debug > $@

models/wikidatawiki.item_quality.gradient_boosting.model: \
		datasets/wikidatawiki.labeling_revisions.w_cache.5k.json
	cat $< | \
	revscoring cv_train \
	  revscoring.scoring.models.GradientBoosting \
	  articlequality.feature_lists.wikidatawiki.item_quality \
	  item_quality \
	  --version $(item_quality_major_minor).0 \
	  -p 'learning_rate=0.01' \
	  -p 'n_estimators=500' \
	  -p 'max_features="log2"' \
	  -p 'max_depth=5' \
	  --labels '"A","B","C","D","E"' \
	  --center --scale > $@

	revscoring model_info $@ > model_info/wikidatawiki.item_quality.md

wikidatawiki_models: \
	models/wikidatawiki.item_quality.gradient_boosting.model

wikidatawiki_tuning_reports: \
	tuning_reports/wikidatawiki.item_quality.md
