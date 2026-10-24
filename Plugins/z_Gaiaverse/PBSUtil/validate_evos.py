def validate_row(row):
    region = region_map[row["Region"]]
    num = int(row["Dex"])
    species = row["Species"].upper()
    form = form_map.get(row["Form"],0)

    species = normalize_special_forms(species, form)

    if species not in pbs:
        raise Exception(f"{species} not found in pokemon.txt")

    if species in rules:
        allowed = rules[species].get(str(form),[])
        if row["Region"] not in allowed:
            raise Exception(
                f"{species} form {form} illegal in {row['Region']}"
            )

    return (region,num,species,form)