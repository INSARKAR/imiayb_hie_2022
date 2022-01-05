####
# imia yearbook hie survey 2022
#
# Indra Neil Sarkar, PhD, MLIS, FACMI
# Rhode Island Quality Institute & Brown University
#
# original version: 2021-12-08
#
# written for Julia 1.7 
###

using HTTP

### Function to search based on submitted PubMed query
### Input  : PubMed Search Query
### Returns: (1) fetch results (in MEDLINE format)
###          (2) MeSH descriptor counts (sans stop MeSH descriptors)
function runsearch(query_term)

    # indicate query to user
    println()
    println(query_term)

    # define base URL
    base_search_query = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"

    # define query dictionary to send to the URL
    query_dict = Dict()
    query_dict["db"] = "pubmed"
    query_dict["term"] = query_term
    query_dict["retmax"] = 0

    # send base query to esearch
    search_result = ""
    try
        search_result = String(HTTP.post(base_search_query, body=HTTP.escapeuri(query_dict)))
    catch
        sleep(10)
        search_result = String(HTTP.post(base_search_query, body=HTTP.escapeuri(query_dict)))
    end

    # retrieve search result count
    search_result_count = parse(Int64, match(r"<eSearchResult><Count>(\d+)</Count>", search_result)[1])
    query_dict["retmax"] = search_result_count

    # send base query to esearch
    search_result = ""
    try
        search_result = String(HTTP.post(base_search_query, body=HTTP.escapeuri(query_dict)))
    catch
        sleep(10)
        search_result = String(HTTP.post(base_search_query, body=HTTP.escapeuri(query_dict)))
    end

    # instantiate pmid_set
    pmid_set = Set()

    # parse through each result line
    for result_line in split(search_result, "\n")
       
        # use a regular expression to capture the PMIDs from 
        # lines that match the pattern
        pmid_capture = match(r"<Id>(\d+)<\/Id>", result_line)

        # only push pmids for lines that contain the pattern
        if pmid_capture != nothing
            push!(pmid_set, pmid_capture[1])
        end

    end

    # indicate how many PMIDs are found
    println("==> $(length(pmid_set))")

    # convert set to a comma list
    id_string = join(collect(pmid_set), ",")

    # update query dictionary for fetch query
    base_fetch_query = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
    query_dict["db"] = "pubmed"
    query_dict["id"] = id_string
    query_dict["rettype"] = "medline"
    query_dict["retmode"] = "text"

    # send query dictionary to efetch
    fetch_result = ""
    try
        fetch_result = String(HTTP.post(base_fetch_query, body=HTTP.escapeuri(query_dict)))
    catch
        sleep(10)
        fetch_result = String(HTTP.post(base_fetch_query, body=HTTP.escapeuri(query_dict)))
    end 

    # instantiate MeSH dictionary
    mesh_dict = Dict()

    # pull out MeSH descriptors from efetch results
    for fetch_line in split(fetch_result, "\n")
        
        # define the MeSH capture RegEx
        mesh_capture = match(r"MH  - \*?([^/]+)", fetch_line)

        # if the line has the pattern, extract the MeSH descriptor
        # and store into MeSH dictionary & tracking frequency
        if mesh_capture != nothing

            # store MeSH descriptors, keeping track of occurence 
            if haskey(mesh_dict, mesh_capture[1])
                mesh_dict[mesh_capture[1]] += 1
            else
                mesh_dict[mesh_capture[1]] = 1
            end

        end

    end

    # define set of stop MeSH descriptors to ignore
    mesh_stop_words = Set()
    push!(mesh_stop_words, "Humans")
    push!(mesh_stop_words, "Female")
    push!(mesh_stop_words, "Male")
    push!(mesh_stop_words, "Adult")
    push!(mesh_stop_words, "Middle Aged")
    push!(mesh_stop_words, "United States")
    push!(mesh_stop_words, "Young Adult")
    push!(mesh_stop_words, "Aged, 80 and over")
    push!(mesh_stop_words, "Adolescent")
    push!(mesh_stop_words, "Medical Informatics")
    push!(mesh_stop_words, "Japan")
    push!(mesh_stop_words, "Aged")
    push!(mesh_stop_words, "Health Information Exchange")
    push!(mesh_stop_words, "Electronic Health Records")
    push!(mesh_stop_words, "Internet")
    push!(mesh_stop_words, "Surveys and Questionnaires")
    push!(mesh_stop_words, "Qualitative Research")
    push!(mesh_stop_words, "Interviews as Topic")
    push!(mesh_stop_words, "Retrospective Studies")
    push!(mesh_stop_words, "Cross-Sectional Studies")
    push!(mesh_stop_words, "Medical Records Systems, Computerized")
    push!(mesh_stop_words, "Reproducibility of Results")
    push!(mesh_stop_words, "Child")

    # store counts of MeSH descriptors into return_mesh_dict
    return_mesh_dict = Dict()
    for mesh_tuple in sort(collect(mesh_dict), by=tuple -> last(tuple), rev=true) #keys(mesh_dict)

        descriptor = mesh_tuple[1]
        count      = mesh_tuple[2]

        if count > 1 && !in(descriptor, mesh_stop_words)
            return_mesh_dict[descriptor] = count
        end

    end

    # return the results of the search and MeSH counts
    return fetch_result, return_mesh_dict
end


function top_mesh(output_file_name, mesh_dict)

    output_file = open(output_file_name, "w")

    for mesh_tuple in sort(collect(mesh_dict), by=tuple -> last(tuple), rev=true) #keys(mesh_dict)

        descriptor = mesh_tuple[1]
        count      = mesh_tuple[2]

        print(output_file, "$count | $descriptor\n")

    end

    close(output_file)

end


function main()

    println()

    start_date = "2018/01/01"
    end_date   = "2021/12/01"

    core_search_nodate = "(\"health information exchange\"[majr]) AND English[language] NOT Editorial[pt] NOT Letter[pt]" 
    core_search_onlyReviews = "$core_search_nodate AND English[language] AND (Systematic[sb])"

    health_equity_terms = "(\"Health Knowledge, Attitudes, Practice\"[mh] or healthdisparities[sb])"

    core_search_noCovid = "($core_search_nodate) NOT LitCGeneral[filter]"
    core_search_noCovid_datelimits = "($core_search_noCovid AND English[language] NOT (Systematic[sb] OR Review[pt]) AND ($start_date:$end_date[pdat]))" 
    core_search_noCovid_healthequity = "($core_search_noCovid AND English[language] NOT (Systematic[sb] OR Review[pt]) AND ($start_date:$end_date[pdat])) AND $health_equity_terms"
    
    core_search_yesCovid_datelimits = "($core_search_nodate) AND English[language] AND LitCGeneral[filter] NOT (Systematic[sb] OR Review[pt]) AND ($start_date:$end_date[pdat]))"
    

    top_count = 5 

    result_dir = "results"
    if !isdir(result_dir)
        mkdir(result_dir)
    end

    #query_term = "(\"health information exchange\"[majr] AND ($start_date:$end_date[pdat])) NOT Systematic[sb] NOT LitCGeneral[filter]"

    #***
    #*** only reviews (exclude COVID-19 papers)
    #***

    search_results, search_mesh_dict = runsearch(core_search_onlyReviews)

    output_file = open("$result_dir/hie_review-medline.txt", "w")
    print(output_file, search_results)
    close(output_file)

    top_mesh("$result_dir/hie_reviews-meshCounts.txt", search_mesh_dict)


    #***
    #*** covid-19 search
    #***

    search_results, search_mesh_dict = runsearch(core_search_yesCovid_datelimits)

    output_file = open("$result_dir/hie_covid-medline.txt", "w")
    print(output_file, search_results)
    close(output_file)

    top_mesh("$result_dir/hie_covid-meshCounts.txt", search_mesh_dict)



    #***
    #*** 
    #***

    search_results, search_mesh_dict = runsearch(core_search_noCovid_healthequity)

    output_file = open("$result_dir/hie_equity-medline.txt", "w")
    print(output_file, search_results)
    close(output_file)

    top_mesh("$result_dir/hie_equity-meshCounts.txt", search_mesh_dict)

    #***
    #*** base search 
    #***

    search_results, search_mesh_dict = runsearch(core_search_noCovid_datelimits)

    output_file = open("$result_dir/hie_fullset-medline.txt", "w")
    print(output_file, search_results)
    close(output_file)

    top_mesh("$result_dir/hie_fullset-meshCounts.txt", search_mesh_dict)

    close(output_file)

    #println(search_results)

    #***
    #*** retrieve articles for top x occuring mesh descriptors
    #***

    rank_count = 0
    rank_value = 0
    for mesh_tuple in sort(collect(search_mesh_dict), by=tuple -> last(tuple), rev=true)

        descriptor = mesh_tuple[1]
        count      = mesh_tuple[2]

        if rank_value == 0
            rank_count = 1
            rank_value = count
        end

        if count < rank_value
            rank_count += 1
            rank_value = count
        end

        if top_count < rank_count
            break
        end

        println("$rank_count >> $count | $descriptor")
        subset_query = "$core_search_noCovid_datelimits AND \"$descriptor\"[mh:noexp]"
        #println("  ==> $subset_query")

        search_results, search_mesh_dict = runsearch(subset_query)
        desc_spaced = replace(descriptor, " " => "_")
        output_file = open("$result_dir/hie_top$(rank_count)_$desc_spaced-medline.txt", "w")
        print(output_file, search_results)
        close(output_file)
        

    end
end

main()