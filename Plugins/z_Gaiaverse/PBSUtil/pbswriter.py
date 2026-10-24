def write_regional_dex(entries, families):

    print("Writing regional dex using new generator...")

    from pathlib import Path

    current = Path(__file__).resolve()

    for parent in current.parents:
        if (parent / "PBS").exists():
            project_root = parent
            break
    else:
        raise Exception("PBS folder not found")

    output_path = project_root / "PBS" / "regionaldexes.txt"

    # region -> dex -> species set
    region_species = {}

    for e in entries:

        if e["dex"] is None:
            continue

        region = e["region"]
        species = e["species"]

        region_species.setdefault(region, set()).add(species)

    written = 0

    with open(output_path, "w", encoding="utf-8") as f:

        for region in sorted(region_species.keys()):

            f.write(f"[{region}]\n")

            # species -> regional dex lookup
            species_dex = {}

            for e in entries:

                if e["dex"] is None:
                    continue

                if e["region"] != region:
                    continue

                species_dex[e["species"]] = e["dex"]

            # sort families by earliest dex member
            sorted_families = sorted(
                families,
                key=lambda fam: min(
                    species_dex.get(s, float("inf")) for s in fam
                )
            )

            for family in sorted_families:

                # only keep members that exist in this region
                members = [s for s in family if s in region_species[region]]

                if not members:
                    continue

                # ensure PBS order inside family
                members = [s for s in family if s in members]

                #print("Writing family:", members)
                written += 1
                f.write(",".join(members) + "\n")

    print("Regional dex written to:", output_path)

    return written