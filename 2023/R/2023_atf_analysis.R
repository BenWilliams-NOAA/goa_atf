# load ----
remotes::install_github("afsc-assessments/afscdata")
remotes::install_github("BenWilliams-NOAA/afscassess")
library(afscdata)
library(afscassess)

# globals ----
year <- 2023
species <- "ARTH"
TAC <- c(96969, 97372, 96501) # last three years of tac year-3, year-2, year-1
rec_age = 1 # recruitmemt age

# setup ----
# setup_folders(year)
# accepted_model(2021, "model_name", 2023)

# query data ----
goa_atf(year, off_yr = TRUE)
clean_catch(year, species, TAC = TAC)
bts_biomass(year)

# run proj ----
proj_ak(year=2023, last_full_assess = 2021, species="atf", region="goa", off_yr=TRUE, folder = "update", rec_age = rec_age)

# setup for next year
setup_folders(year+1)
# accepted_model(2021, "model_name", 2024)

# create figures ----
dir.create(here::here(year, "figs"))


## FLAG - need adjusted for specifics of atf





# plot catch/biomass
std <- read.delim(here::here(year, "base", "nr.std"), sep="", header = TRUE)
catch <- vroom::vroom(here::here(year, "data", "output", "fsh_catch.csv"))

filter(catch, year == max(year)) %>%
  left_join(vroom::vroom(here::here(year, folder, "proj", "author_f", "bigsum.csv")) %>%
              filter(Year == year, Alt == 2) %>%
              dplyr::select(year=Year, value = Total_Biom))

std %>%
  filter(name=="tot_biom") %>%
  bind_cols(filter(catch, year < max(year))) %>%
  filter(year >= 1991) %>%
  dplyr::select(year, catch, value, std.dev) %>%
  bind_rows(filter(catch, year == max(year)) %>%
              left_join(vroom::vroom(here::here(year, folder, "proj", "author_f", "bigsum.csv")) %>%
                          filter(Year == year, Alt == 2) %>%
                          mutate(value = Total_Biom * 1000) %>%
                          dplyr::select(year=Year, value))) %>%
  mutate(std.dev = ifelse(is.na(std.dev), std.dev[year==max(year)-1], std.dev)) %>%
  mutate(lci = value - std.dev * 1.96,
         uci = value + std.dev * 1.96) %>%
  mutate(perc = catch / value,
         lci = catch / lci,
         uci = catch / uci,
         mean = mean(perc)) %>%
  dplyr::select(year, value, mean, perc, lci, uci) -> df

png(filename=here::here(year, "figs", "catch_bio.png"), width = 6.5, height = 6.5,
    units = "in", type ="cairo", res = 200)
df %>%
  ggplot2::ggplot(ggplot2::aes(year, perc)) +
  ggplot2::geom_line() +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = lci, ymax = uci), alpha = 0.2) +
  ggplot2::geom_hline(yintercept = df$mean, lty = 3) +
  ggplot2::expand_limits(y = c(0, 0.08)) +
  afscassess::scale_x_tickr(data=df, var=year, start = 1990) +
  afscassess::theme_report() +
  ggplot2::xlab("\nYear") +
  ggplot2::ylab("Catch/Biomass\n")


dev.off()

# plot survey results ----

vast <- vroom::vroom(here::here(year, "data", "user_input", "vast.csv"))
sb <- vroom::vroom(here::here(year, "data", "output",  "goa_total_bts_biomass.csv"))

png(filename=here::here(year, "figs", "bts_biomass.png"), width = 6.5, height = 6.5,
    units = "in", type ="cairo", res = 200)

vast  %>%
  dplyr::mutate(t = biomass,
                Model = "VAST")  %>%
  dplyr::select(-biomass) %>%
  dplyr::bind_rows(sb %>%
                     dplyr::rename(t = biomass) %>%
                     dplyr::mutate(Model = "Design-based") %>%
                     dplyr::select(-se)) %>%
  dplyr::group_by(Model) %>%
  dplyr::mutate(mean = mean(t)) %>%
  dplyr::ungroup() %>%
  ggplot2::ggplot(ggplot2::aes(year, t, fill = Model, color = Model)) +
  ggplot2::geom_point() +
  ggplot2::geom_line() +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = lci, ymax = uci), alpha = 0.2, color = NA) +
  afscassess::scale_x_tickr(data=vast, var=year) +
  ggplot2::scale_y_continuous(labels = scales::comma) +
  ggplot2::ylab("Survey biomass (t)\n") +
  ggplot2::xlab("\nYear") +
  ggplot2::expand_limits(y = 0) +
  scico::scale_fill_scico_d(palette = "roma", begin = 0.2) +
  scico::scale_color_scico_d(palette = "roma", begin = 0.2) +
  ggplot2::geom_line(ggplot2::aes(y = mean), lty = 3) +
  afscassess::theme_report() +
  ggplot2::theme(legend.position = c(0.2, 0.8))

dev.off()
