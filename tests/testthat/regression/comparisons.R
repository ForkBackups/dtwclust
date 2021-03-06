context("\tCompare clusterings")

# =================================================================================================
# setup
# =================================================================================================

## Original objects in env
ols <- ls()

# =================================================================================================
# comparisons
# =================================================================================================

with(persistent, {
    test_that("Compare clusterings gives the same results as references.", {
        skip_on_cran()

        expect_equal_to_reference(all_comp, file_name(all_comp))
        expect_equal_to_reference(gak_comp, file_name(gak_comp))
        expect_equal_to_reference(dba_comp, file_name(dba_comp))
    })
})

# =================================================================================================
# clean
# =================================================================================================
rm(list = setdiff(ls(), ols))
