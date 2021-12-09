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

# define base URL
base_search_query = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"

# define query term
query_term = "(\"health information exchange\"[majr] AND (2018:2021[pdat])) NOT LitCGeneral[filter]"

# define query dictionary to send to the URL
query_dict = Dict()
query_dict["db"] = "pubmed"
query_dict["term"] = query_term
query_dict["retmax"] = 500

# send base query to esearch
search_result = String(HTTP.post(base_search_query, body=HTTP.escapeuri(query_dict)))

# instantiate pmid_set
pmid_set = Set()

# parse through each result line
for result_line in split(search_result, "\n")
    #println("\$\$\$\$\$ $result_line")

    # use a regular expression to capture the PMIDs from 
    # lines that match the pattern
    pmid_capture = match(r"<Id>(\d+)<\/Id>", result_line)

    # only push pmids for lines that contain the pattern
    if pmid_capture != nothing
        push!(pmid_set, pmid_capture[1])
    end

end

println(length(pmid_set))

# convert set to a comma list
id_string = join(collect(pmid_set), ",")

# update query dictionary for fetch query
base_fetch_query = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
query_dict["db"] = "pubmed"
query_dict["id"] = id_string
query_dict["rettype"] = "medline"
query_dict["retmode"] = "text"

# send query dictionary to efetch
fetch_result = String(HTTP.post(base_fetch_query, body=HTTP.escapeuri(query_dict)))

#print(fetch_result)



# instantiate mesh dictionary
mesh_dict = Dict()

# pull out MeSH descriptors from efetch results
for fetch_line in split(fetch_result, "\n")
    
    # define the mesh capture RegEx
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

# print out counts of MeSH descriptors
for mesh_tuple in sort(collect(mesh_dict), by=tuple -> last(tuple), rev=true) #keys(mesh_dict)

    descriptor = mesh_tuple[1]
    count      = mesh_tuple[2]

    if count > 10 && !in(descriptor, mesh_stop_words)
        println("$descriptor >> $count")
    end

    # if mesh_dict[mesh_descriptor] > 1
    #     println("$mesh_descriptor occurs $(mesh_dict[mesh_descriptor]) times")
    # end
end