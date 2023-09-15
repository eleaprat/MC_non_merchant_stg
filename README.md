# MC_non_merchant_stg
You can find here the code for the article ["XX"](http://arxiv.org/).

## Results from the paper
The csv files contain the network data and are gathered in a Python script:
 * **baseMVA.csv, branch.csv, bus.csv, gen.csv, gencost.csv, PTDF.csv**: Network data.
 * **Case.py**: Builds the case file from the different csv files.
 * **requests.csv**: Flexibility requests.
 * **offers.csv**: Flexibility offers.

## Run examples
The script **Market_clearing.py** should be run to simulate the matching of the requests in **requests.csv** and the offers **offers.csv** in by the continuous market.
