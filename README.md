# York Gillygate Air Quality Data

Open reproduction of York Gillygate air quality data analysis.

## Results

See interactive plots at https://mbdriscoll.github.io/gillygate-deweather/ .

## Usage

Download weather and air quality data for the locations and time period of your choice. Here, we download weather data from RAF Topcliffe and air quality data from the York Gillygate sensor (YK7) for the past five years.

```bash
./download_met_aq_data.r EGXZ YK7 5 aqe
```

This produces a csv file `met_EGXZ_aq_YK7_aqe_2021_to_2025.csv`. Then, we apply the deweathering operation to it:

```bash
./apply-deweathering.r met_EGXZ_aq_YK7_aqe_2021_to_2025.csv
```

This produces another file `met_EGXZ_aq_YK7_aqe_2021_to_2025_normalised.csv` with extra columns for the weather-adjusted values ('no_norm', 'nox_norm', 'no2_norm').

Plot that with the plotting software of your choice.

## Data Sources

### Weather Stations

Weather station codes are:

* RAF Church Fenton: EGCM
* RAF Topcliffe: EGXZ
* RAF Linton-on-Ouse: EGXU


### Air Quality Sensors

See [Air Quality England's page for CYC](https://www.airqualityengland.co.uk/local-authority/?la_id=76).

