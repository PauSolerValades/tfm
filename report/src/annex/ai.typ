Following the required conventions of Universitat Politècnica de Catalunya @upc-ia-guia this annex specifies which tools that use generative AI and for which purpose have they been used.

== Models

The models used are the following:
- Google Gemini 3.1 Pro @gemini-3-1-pro
- DeepSeek v4 Pro @deepseek-v4

With the following tools:
- Google Gemini app @gemini-app: offers a chatbot interface to talk to the models.
- Pi coding agent @pi-dev: terminal utility that uses ai agents to execute commands in the users computer.

== Purpose

The models have been used for the following utilities:
- Reference finding and content exploration, together with Google Scholar.
- Summary and ease of understanding of academic papers in State of the Art (@sec-sota).
- Enhancing prose and correcting spelling and style in all written sections.
- Assistance in code writing used in Data, Calibration, Execution and Results (@sec-data, @sec-calibration, @sec-exec, @sec-results respectively)
- Reference formatting.

Generative AI has NOT been used in the following tasks:
- Any code written in Zig (Implementation, @sec-impl) or concerning the simulation.
- Any decision taking regarding technology election, _e.g_ the use of the Go programming language or R, the use of DuckDB/SQLite database technology, the use of parquet files.
- Pipeline design: which transformations to apply to the data in order to obtain some results from it.
- Any interpretation of the data, as well as results obtained from it.

What the above points imply can be distilled in the following statement:

_Every piece of text written in this report is human born, human written and AI corrected. Every idea in this thesis is human born and humanly discussed, with AI consultance. Every line of Zig and programming decision is human born and human executed. Every conclusion and every reasoning about data is human born, and human executed._



