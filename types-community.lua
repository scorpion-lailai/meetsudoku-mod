---@meta

---@class CommunityPluginManifest
---@field manifestVersion 3
---@field id string
---@field name string
---@field version string
---Script V1 author manifest. The Host supplies API 5, Lua runtime, entry,
---capabilities, permissions, resources and dependencies.

---@class CommunityBoard
---@field size 9
---@field cells integer[][] 1-based rows/columns; 0 means empty

---@class CommunityHost
---@field api_version 1|2|3|4|5
---@field platform "windows"|"macos"|"linux"|"steamos"

---@class CommunityVariant
---@field id string
---@field base "sudoku_9x9"
---@field capabilities { [1]: "community_variant" }

---@class CommunityPuzzle
---@field content_id string
---@field puzzle_id string
---@field puzzle string 81-character puzzle string; 0 means empty
---@field rules CommunityRuleInstance[] immutable puzzle rule instances

---@class CommunityRuleInstance
---@field id string reusable Lua-owned rule id
---@field data table immutable puzzle-specific JSON data

---@class CommunitySession
---@field content_hash string
---@field api_version 1|2|3|4|5
---@field base_rule_family "sudoku_9x9"

---@class CommunityCandidateCellRequest
---@field row integer 0-based
---@field col integer 0-based
---@field baseCandidates integer[] sorted Host-owned classic candidates

---@class CommunityMetadata
---@field phase string|nil lifecycle phase when present
---@field phase "community_session_initialize"|"community_rule_compile"|"community_overlay_compile"|"community_session_shutdown"|nil

---@class CommunityPluginLog
local CommunityPluginLog = {}

---@param message string
function CommunityPluginLog:debug(message) end

---@param message string
function CommunityPluginLog:info(message) end

---@param message string
function CommunityPluginLog:warn(message) end

---@param message string
function CommunityPluginLog:error(message) end

---@class CommunityContext
---@field board CommunityBoard
---@field host CommunityHost
---@field variant CommunityVariant
---@field puzzle CommunityPuzzle
---@field session CommunitySession
---@field metadata CommunityMetadata
---@field log CommunityPluginLog

---@class CommunityOverlayPoint
---@field x number board units in 0.0..9.0
---@field y number board units in 0.0..9.0

---@class CommunityOverlayThemeColor
---@field theme "constraint_line"|"constraint_fill" Host semantic theme color

---@class CommunityOverlayPaint
---@field stroke string|CommunityOverlayThemeColor|nil #RRGGBB, #RRGGBBAA with trailing alpha, or a Host theme color; not 0xAARRGGBB
---@field fill string|CommunityOverlayThemeColor|nil #RRGGBB, #RRGGBBAA with trailing alpha, or a Host theme color; not 0xAARRGGBB
---@field stroke_width number|nil positive, at most 1.0 board unit
---@field opacity number|nil 0.0..1.0
---@field cap "butt"|"round"|"square"|nil
---@field join "miter"|"round"|"bevel"|nil
---@field text_size number|nil positive, at most 1.0 board unit
---@field text_align "left"|"center"|"right"|nil

---@class CommunityOverlayBuiltinIr
---@field type "builtin"
---@field kind "thermometer"|"edge_label"|"arrow"|"killer_cage"|"parity_mark"|"boundary_label"|"outside_ray_clue"|"board_level_numeric_clue"
---@field data table|CommunityOverlayBoundaryLabelData|CommunityOverlayOutsideRayClueData kind-specific bounded data
---@field style string|nil Host semantic style name; forbidden for outside_ray_clue

---@class CommunityOverlayBoundaryLabelData
---@field axis "row"|"column"
---@field side "left"|"right"|"top"|"bottom"|nil row permits left/right; column permits top/bottom; defaults to left/top
---@field index integer 0..8 row or column index
---@field label string decimal text in the range 0..45

---@class CommunityOverlayOutsideRayEntry
---@field side "top"|"right"|"bottom"|"left" board side where the ray enters
---@field index integer 0..8 column index for top/bottom or row index for left/right

---@class CommunityOverlayOutsideRayClueData
---@field entry CommunityOverlayOutsideRayEntry
---@field direction "down_right"|"down_left"|"up_right"|"up_left" absolute inward diagonal direction
---@field value integer decimal clue value in 1..81

---@class CommunityOverlayBoardLevelNumericClueData
---@field value integer board-wide numeric clue in 0..81; Host owns its placement and appearance

---@class CommunityOverlayCustomBaseIr
---@field style string|nil exactly one of style or paint
---@field paint CommunityOverlayPaint|nil exactly one of style or paint

---@class CommunityOverlayLineIr: CommunityOverlayCustomBaseIr
---@field type "line"
---@field from CommunityOverlayPoint
---@field to CommunityOverlayPoint

---@class CommunityOverlayPolylineIr: CommunityOverlayCustomBaseIr
---@field type "polyline"
---@field points CommunityOverlayPoint[] at least two points

---@class CommunityOverlayCircleIr: CommunityOverlayCustomBaseIr
---@field type "circle"
---@field center CommunityOverlayPoint
---@field radius number positive radius within board bounds

---@class CommunityOverlayRectIr: CommunityOverlayCustomBaseIr
---@field type "rect"
---@field origin CommunityOverlayPoint top-left board coordinate
---@field width number positive width within board bounds
---@field height number positive height within board bounds

---@class CommunityOverlayPolygonIr: CommunityOverlayCustomBaseIr
---@field type "polygon"
---@field points CommunityOverlayPoint[] at least three points

---@class CommunityOverlayPathMoveToIr
---@field op "move_to"
---@field x number
---@field y number

---@class CommunityOverlayPathLineToIr
---@field op "line_to"
---@field x number
---@field y number

---@class CommunityOverlayPathQuadToIr
---@field op "quad_to"
---@field cx number
---@field cy number
---@field x number
---@field y number

---@class CommunityOverlayPathCubicToIr
---@field op "cubic_to"
---@field c1x number
---@field c1y number
---@field c2x number
---@field c2y number
---@field x number
---@field y number

---@class CommunityOverlayPathCloseIr
---@field op "close"

---@alias CommunityOverlayPathCommandIr CommunityOverlayPathMoveToIr|CommunityOverlayPathLineToIr|CommunityOverlayPathQuadToIr|CommunityOverlayPathCubicToIr|CommunityOverlayPathCloseIr

---@class CommunityOverlayPathIr: CommunityOverlayCustomBaseIr
---@field type "path"
---@field commands CommunityOverlayPathCommandIr[] starts with move_to

---@class CommunityOverlayTextIr: CommunityOverlayCustomBaseIr
---@field type "text"
---@field position CommunityOverlayPoint
---@field value string short display text

---@alias CommunityOverlayCustomIr CommunityOverlayLineIr|CommunityOverlayPolylineIr|CommunityOverlayCircleIr|CommunityOverlayRectIr|CommunityOverlayPolygonIr|CommunityOverlayPathIr|CommunityOverlayTextIr

---@alias CommunityOverlayPrimitiveIr CommunityOverlayBuiltinIr|CommunityOverlayCustomIr

---@class CommunityOverlayCompileResult
---@field primitives CommunityOverlayPrimitiveIr[] max 64 primitives

---@class CommunityRuleCompileScope
---@field rule_id string current rules[].id handler key
---@field rule_index integer current 1-based rules[] position
local CommunityRuleCompileScope = {}

---@param local_id string lower-snake-case id local to this rule declaration
---@return string id globally unique for the current rules[] order
function CommunityRuleCompileScope:constraint_id(local_id) end

---@class CommunityBoardApi
---Read-only access to the normalized Host board snapshot.
local CommunityBoardApi = {}

---@param value integer|nil
---@return boolean
function CommunityBoardApi.is_empty(value) end

---@param ctx CommunityContext
---@param cell integer zero-based row-major cell index in 0..80
---@return integer digit in 0..9; 0 means empty
function CommunityBoardApi.value(ctx, cell) end

---@class CommunityCellApi
---Zero-based 9x9 cell index validation and conversion helpers.
local CommunityCellApi = {}

---@param value any
---@param name? string diagnostic field name
---@return integer cell zero-based row-major index in 0..80
function CommunityCellApi.expect(value, name) end

---@param cell integer zero-based row-major cell index in 0..80
---@return integer row zero-based row in 0..8
function CommunityCellApi.row(cell) end

---@param cell integer zero-based row-major cell index in 0..80
---@return integer column zero-based column in 0..8
function CommunityCellApi.column(cell) end

---@param row integer zero-based row in 0..8
---@param column integer zero-based column in 0..8
---@return integer cell zero-based row-major index in 0..80
function CommunityCellApi.index(row, column) end

---@class CommunitySchemaApi
---Bounded validation for author-owned puzzle configuration tables.
local CommunitySchemaApi = {}

---@param value any
---@param name? string diagnostic field name
---@return integer
function CommunitySchemaApi.expect_integer(value, name) end

---@param value any
---@param minimum integer minimum array length
---@param maximum integer maximum array length
---@param name? string diagnostic field name
---@return table validated dense array
function CommunitySchemaApi.expect_array(value, minimum, maximum, name) end

---@param value any
---@param allowed table<string, boolean> keys mapped to true
---@param name? string diagnostic field name
---@return table validated object
function CommunitySchemaApi.expect_exact_keys(value, allowed, name) end

---@class CommunityAdjacencyApi
---Variant-neutral cell adjacency tests.
local CommunityAdjacencyApi = {}

---@param first integer zero-based cell index
---@param second integer zero-based cell index
---@return boolean whether the cells share an edge
function CommunityAdjacencyApi.orthogonal(first, second) end

---@param first integer zero-based cell index
---@param second integer zero-based cell index
---@return boolean whether distinct cells touch by an edge or corner
function CommunityAdjacencyApi.eight_way(first, second) end

---@class CommunityPathApi
---Variant-neutral stable identity helpers for edges and ordered paths.
local CommunityPathApi = {}

---@param first integer zero-based cell index
---@param second integer zero-based cell index distinct from first
---@return string stable direction-independent edge key
function CommunityPathApi.edge_key(first, second) end

---@param cells integer[] dense array of zero-based cell indexes
---@return string stable key shared by a path and its reversal
function CommunityPathApi.canonical_key(cells) end

---@class CommunityOverlayGeometryApi
---Bounded conversion from Sudoku cell geometry to Overlay board-unit points.
local CommunityOverlayGeometryApi = {}

---@param cell integer zero-based cell index in 0..80
---@return CommunityOverlayPoint center point in board units
function CommunityOverlayGeometryApi.cell_center(cell) end

---@param cells integer[] dense array containing 1..64 zero-based cell indexes; order and duplicates are preserved
---@return CommunityOverlayPoint[] center points in the same order
function CommunityOverlayGeometryApi.cell_centers(cells) end

---@param first integer zero-based cell index
---@param second integer distinct orthogonally adjacent zero-based cell index
---@return CommunityOverlayPoint midpoint of the shared edge in board units
function CommunityOverlayGeometryApi.edge_center(first, second) end

---@class CommunityVariantSdk
---@field constraint CommunityConstraintProgramApi typed Constraint Program helpers for the current Script V1 contract
---@field board CommunityBoardApi read-only normalized board access
---@field cell CommunityCellApi zero-based 9x9 index helpers
---@field schema CommunitySchemaApi bounded author-data validation
---@field adjacency CommunityAdjacencyApi variant-neutral cell adjacency tests
---@field path CommunityPathApi variant-neutral stable path identity helpers
---@field overlay_geometry CommunityOverlayGeometryApi bounded cell-to-Overlay coordinate helpers
local CommunityVariantSdk = {}

---@class CommunityConstraintProgramConstant
---@field op "constant"
---@field value integer signed 32-bit literal

---@class CommunityConstraintProgramValue
---@field op "value"
---@field cell integer row-major cell index in 0..80

---@class CommunityConstraintProgramRemainder
---@field op "remainder"
---@field arg CommunityConstraintProgramValue direct cell value expression
---@field divisor integer literal divisor in 2..9

---@class CommunityConstraintProgramSum
---@field op "sum"
---@field args CommunityConstraintProgramIntegerExpression[] 1..81 expressions; multiplicity is preserved

---@class CommunityConstraintProgramCount
---@field op "count"
---@field predicates CommunityConstraintProgramPredicate[] 1..64 predicates; canonical order is Host-normalized and multiplicity is preserved

---@class CommunityConstraintProgramElement
---@field op "element"
---@field cells integer[] exactly 9 unique row-major cell indexes in semantic order
---@field index CommunityConstraintProgramValue one-based selector value

---@alias CommunityConstraintProgramIntegerExpression CommunityConstraintProgramConstant|CommunityConstraintProgramValue|CommunityConstraintProgramRemainder|CommunityConstraintProgramSum|CommunityConstraintProgramCount|CommunityConstraintProgramElement

---@class CommunityConstraintProgramEqual
---@field op "equal"
---@field left CommunityConstraintProgramIntegerExpression
---@field right CommunityConstraintProgramIntegerExpression

---@class CommunityConstraintProgramNotEqual
---@field op "not_equal"
---@field left CommunityConstraintProgramIntegerExpression
---@field right CommunityConstraintProgramIntegerExpression

---@class CommunityConstraintProgramLessThan
---@field op "less_than"
---@field left CommunityConstraintProgramIntegerExpression canonical expression order
---@field right CommunityConstraintProgramIntegerExpression

---@class CommunityConstraintProgramGreaterThan
---@field op "greater_than"
---@field left CommunityConstraintProgramIntegerExpression canonical expression order
---@field right CommunityConstraintProgramIntegerExpression

---@class CommunityConstraintProgramLessThanOrEqual
---@field op "less_than_or_equal"
---@field left CommunityConstraintProgramIntegerExpression canonical expression order
---@field right CommunityConstraintProgramIntegerExpression

---@class CommunityConstraintProgramGreaterThanOrEqual
---@field op "greater_than_or_equal"
---@field left CommunityConstraintProgramIntegerExpression canonical expression order
---@field right CommunityConstraintProgramIntegerExpression

---@class CommunityConstraintProgramAllDifferent
---@field op "all_different"
---@field cells integer[] row-major cell indexes in 0..80

---@class CommunityConstraintProgramSelfReferentialFrequency
---@field op "self_referential_frequency_group"
---@field cells integer[] 1..9 unique canonical row-major cell indexes

---@class CommunityConstraintProgramMultisetEqual
---@field op "multiset_equal_group"
---@field first integer[] first canonical cell group
---@field second integer[] second canonical cell group

---@class CommunityConstraintProgramValueSelectedPairSumEqualsConstant
---@field op "value_selected_pair_sum_equals_constant"
---@field cells integer[] exactly 9 ordered, unique row-major cell indexes
---@field firstIndexCell integer zero-based selector cell
---@field secondIndexCell integer distinct zero-based selector cell
---@field target integer fixed target in 2..18

---@class CommunityConstraintProgramExactSumEqualsConstant
---@field op "exact_sum_equals_constant"
---@field cells integer[] 2..4 unique row-major cell indexes; order is normalized
---@field target integer fixed target in cell count..9 * cell count

---@class CommunityConstraintProgramAnd
---@field op "and"
---@field predicates CommunityConstraintProgramPredicate[] 2..64 unique predicates; canonical order is Host-normalized

---@class CommunityConstraintProgramOr
---@field op "or"
---@field predicates CommunityConstraintProgramPredicate[] 2..16 unique predicates; canonical order is Host-normalized

---@class CommunityConstraintProgramNot
---@field op "not"
---@field predicate CommunityConstraintProgramPredicate

---@alias CommunityConstraintProgramPredicate CommunityConstraintProgramAllDifferent|CommunityConstraintProgramSelfReferentialFrequency|CommunityConstraintProgramMultisetEqual|CommunityConstraintProgramValueSelectedPairSumEqualsConstant|CommunityConstraintProgramExactSumEqualsConstant|CommunityConstraintProgramEqual|CommunityConstraintProgramNotEqual|CommunityConstraintProgramLessThan|CommunityConstraintProgramGreaterThan|CommunityConstraintProgramLessThanOrEqual|CommunityConstraintProgramGreaterThanOrEqual|CommunityConstraintProgramAnd|CommunityConstraintProgramOr|CommunityConstraintProgramNot

---@class CommunityConstraintProgramApi
---Typed startup-only constructors for the graduated Constraint Program AST in
---the current Script V1 contract. These helpers do not evaluate boards and do
---not execute during Gameplay; the Host remains responsible for validation,
---canonicalization, hashing and native materialization. API 1--4 remain
---legacy reader compatibility only and are not an alternate authoring entry.
local CommunityConstraintProgramApi = {}

---@param cell integer zero-based row-major cell index in 0..80
---@return CommunityConstraintProgramValue
function CommunityConstraintProgramApi.value(cell) end

---@param value integer signed 32-bit literal
---@return CommunityConstraintProgramConstant
function CommunityConstraintProgramApi.constant(value) end

---Builds a bounded non-negative remainder expression. The initial Community
---exposure accepts it only as a direct comparison operand and requires a direct
---value(cell) argument.
---@param value_expression CommunityConstraintProgramValue
---@param divisor integer literal divisor in 2..9
---@return CommunityConstraintProgramRemainder
function CommunityConstraintProgramApi.remainder(value_expression, divisor) end

---Builds a sum and canonicalizes argument order while preserving multiplicity.
---@param args CommunityConstraintProgramIntegerExpression[] 1..81 expressions; multiplicity is preserved
---@return CommunityConstraintProgramSum
function CommunityConstraintProgramApi.sum(args) end

---@param predicates CommunityConstraintProgramPredicate[] 1..64 predicates; multiplicity is preserved
---@return CommunityConstraintProgramCount
function CommunityConstraintProgramApi.count(predicates) end

---Builds a one-based dynamic read from an ordered nine-cell sequence. The initial
---Community exposure accepts this expression only as the direct left operand of
---equal(element_at(...), constant(1..9)).
---@param cells integer[] exactly 9 unique row-major cell indexes in semantic order
---@param index_expression CommunityConstraintProgramValue direct value(index_cell)
---@return CommunityConstraintProgramElement
function CommunityConstraintProgramApi.element_at(cells, index_expression) end

---@param left CommunityConstraintProgramIntegerExpression automatically canonicalized with right
---@param right CommunityConstraintProgramIntegerExpression automatically canonicalized with left
---@return CommunityConstraintProgramEqual
function CommunityConstraintProgramApi.equal(left, right) end

---@param left CommunityConstraintProgramIntegerExpression automatically canonicalized with right
---@param right CommunityConstraintProgramIntegerExpression automatically canonicalized with left
---@return CommunityConstraintProgramNotEqual
function CommunityConstraintProgramApi.not_equal(left, right) end

---Expresses left < right. The SDK canonicalizes operand order and inverts the returned operator when needed.
---@param left CommunityConstraintProgramIntegerExpression semantic left operand
---@param right CommunityConstraintProgramIntegerExpression
---@return CommunityConstraintProgramLessThan|CommunityConstraintProgramGreaterThan
function CommunityConstraintProgramApi.less_than(left, right) end

---Expresses left <= right. The SDK canonicalizes operand order and inverts the returned operator when needed.
---@param left CommunityConstraintProgramIntegerExpression semantic left operand
---@param right CommunityConstraintProgramIntegerExpression
---@return CommunityConstraintProgramLessThanOrEqual|CommunityConstraintProgramGreaterThanOrEqual
function CommunityConstraintProgramApi.less_than_or_equal(left, right) end

---Expresses left > right. The SDK canonicalizes operand order and inverts the returned operator when needed.
---@param left CommunityConstraintProgramIntegerExpression semantic left operand
---@param right CommunityConstraintProgramIntegerExpression
---@return CommunityConstraintProgramGreaterThan|CommunityConstraintProgramLessThan
function CommunityConstraintProgramApi.greater_than(left, right) end

---Expresses left >= right. The SDK canonicalizes operand order and inverts the returned operator when needed.
---@param left CommunityConstraintProgramIntegerExpression semantic left operand
---@param right CommunityConstraintProgramIntegerExpression
---@return CommunityConstraintProgramGreaterThanOrEqual|CommunityConstraintProgramLessThanOrEqual
function CommunityConstraintProgramApi.greater_than_or_equal(left, right) end

---@param cells integer[] 2..9 unique zero-based cell indexes
---@return CommunityConstraintProgramAllDifferent
function CommunityConstraintProgramApi.all_different(cells) end

---Requires every digit present in the group to occur exactly that many times,
---including the cell carrying the digit. This predicate is root-only in V1.
---@param cells integer[] 1..9 unique zero-based cell indexes; order is canonicalized
---@return CommunityConstraintProgramSelfReferentialFrequency
function CommunityConstraintProgramApi.self_referential_frequency(cells) end

---Requires two disjoint groups to contain the same digit multiset. Duplicate
---digits count; cell order does not. This predicate is root-only in V1.
---@param first_cells integer[] 1..9 unique zero-based cell indexes
---@param second_cells integer[] same length as first_cells, unique and disjoint
---@return CommunityConstraintProgramMultisetEqual
function CommunityConstraintProgramApi.multiset_equal(first_cells, second_cells) end

---Selects two one-based positions from an ordered nine-cell sequence using
---the values in two distinct selector cells, then requires those selected
---digits to sum to a fixed target. This predicate is root-only in V1.
---@param cells integer[] exactly 9 ordered, unique zero-based cell indexes
---@param first_index_cell integer distinct zero-based selector cell
---@param second_index_cell integer distinct zero-based selector cell
---@param target integer fixed target in 2..18
---@return CommunityConstraintProgramValueSelectedPairSumEqualsConstant
function CommunityConstraintProgramApi.value_selected_pair_sum_equals_constant(
    cells,
    first_index_cell,
    second_index_cell,
    target)
end

---@param cells integer[] 2..4 distinct zero-based cells; order is normalized
---@param target integer reachable total in cell count..9 * cell count
---@return CommunityConstraintProgramExactSumEqualsConstant root-only exact-sum predicate
function CommunityConstraintProgramApi.exact_sum_equals_constant(cells, target) end

---@param predicates CommunityConstraintProgramPredicate[] 2..64 unique predicates
---@return CommunityConstraintProgramAnd
function CommunityConstraintProgramApi.and_(predicates) end

---@param predicates CommunityConstraintProgramPredicate[] 2..16 unique predicates
---@return CommunityConstraintProgramOr
function CommunityConstraintProgramApi.or_(predicates) end

---@param predicate CommunityConstraintProgramPredicate
---@return CommunityConstraintProgramNot
function CommunityConstraintProgramApi.not_(predicate) end

---@field all fun(predicates: CommunityConstraintProgramPredicate[]): CommunityConstraintProgramAnd alias for and_
---@field any fun(predicates: CommunityConstraintProgramPredicate[]): CommunityConstraintProgramOr alias for or_
---@field negate fun(predicate: CommunityConstraintProgramPredicate): CommunityConstraintProgramNot alias for not_
---@field ["and"] fun(predicates: CommunityConstraintProgramPredicate[]): CommunityConstraintProgramAnd
---@field ["or"] fun(predicates: CommunityConstraintProgramPredicate[]): CommunityConstraintProgramOr
---@field ["not"] fun(predicate: CommunityConstraintProgramPredicate): CommunityConstraintProgramNot

---@class CommunityScriptMove
---@field cell integer zero-based row-major cell index in 0..80
---@field digit integer proposed digit in 1..9, or 0 for clearing

---@class CommunityScriptViolation
---@field code string author-owned bounded violation code
---@field cells integer[] zero-based affected cells
---@field data? table optional bounded diagnostic data

---@class CommunityScriptValidationResult
---@field violations CommunityScriptViolation[]
---@field observation? CommunityScriptBoardObservation optional current-board positive cell observation; omitted means no observation
---@field diagnostics table[]

---@class CommunityScriptBoardObservation
---@field active_cells integer[] ascending, duplicate-free zero-based cells in 0..80 whose filled digit positively satisfies this rule's player-visible per-cell condition

---@class CommunityScriptMoveValidationResult
---@field accepted boolean
---@field violations CommunityScriptViolation[]
---@field diagnostics table[]

---@class CommunityScriptCandidateEliminationResult
---@field remove integer[] digits to remove from Host-owned candidates
---@field reasons table<string, string> digit string to reason code
---@field diagnostics table[]

---@alias CommunityScriptCandidateScope integer[] dense, non-empty, unique zero-based cell indexes in 0..80; a safe superset of cells whose candidates this rule may remove

---@class CommunityScriptCompletionResult
---@field valid boolean
---@field violations CommunityScriptViolation[]
---@field diagnostics table[]

---@class CommunityScriptRuleInstance
---@field validate_move fun(ctx: CommunityContext, move: CommunityScriptMove): CommunityScriptMoveValidationResult required; validates a Host-owned move transaction
---@field validate_board fun(ctx: CommunityContext): CommunityScriptValidationResult required; reports current-board violations
---@field candidate_scope? fun(): CommunityScriptCandidateScope required exactly when get_candidate_eliminations exists; derived from normalized rule geometry, not puzzle JSON
---@field get_candidate_eliminations? fun(ctx: CommunityContext, cell: integer, base_candidates?: integer[]): CommunityScriptCandidateEliminationResult optional candidate removals only; Host invokes only empty cells in candidate_scope and may pass narrowed Host-owned requested digits
---@field validate_final_state fun(ctx: CommunityContext): CommunityScriptCompletionResult required; reports whether this rule is valid for final-state checks
---@field build_overlay? fun(ctx: CommunityContext): CommunityOverlayCompileResult optional startup declarative overlay
---@field build_session_features? fun(ctx: CommunityContext): CommunitySessionFeatureCompileResult optional startup declarative session feature IR

---@class CommunityScriptMaterializedDefinition
---@field base_topology? CommunityScriptBaseTopology optional replacement topology declared at startup
---@field constraints? CommunityConstraintProgramPredicate[] 0..64 startup predicates compiled into the Native Rule Graph; required unless base_topology is present
---@field overlay? CommunityOverlayCompileResult optional startup declarative overlay

---@class CommunityScriptBaseTopology
---@field type "row_column_only"|"explicit_regions"

---@class CommunityScriptMaterializedRuleHandler
---@field define fun(config: table, scope: CommunityRuleCompileScope): CommunityScriptMaterializedDefinition startup-only semantic definition; mutually exclusive with create

---@class CommunityScriptRuntimeRuleHandler
---@field create fun(config: table, scope: CommunityRuleCompileScope): CommunityScriptRuleInstance called once per puzzle rule for each exact session, then reused across startup and gameplay surfaces; mutually exclusive with define

---@alias CommunityScriptRuleHandler CommunityScriptMaterializedRuleHandler|CommunityScriptRuntimeRuleHandler

---@class CommunityScriptBuilder
local CommunityScriptBuilder = {}

---@param id string lower-snake-case rules[].id handler key
---@param handler CommunityScriptRuleHandler
---@return CommunityScriptBuilder
function CommunityScriptBuilder:register_rule(id, handler) end

---@return CommunityScriptBuildResult opaque Script V1 rule declaration consumed by the Host
function CommunityScriptBuilder:build() end

---@class CommunitySessionFeatureCompileResult
---@field features CommunitySessionFeatureSemanticDefinition[] startup semantic feature declarations

---@alias CommunitySessionFeatureSemanticDefinition CommunityCellStateRuleSemanticDefinition

---@class CommunityCellStateRuleSemanticDefinition
---@field kind "cell_state_rule"
---@field states CommunityCellStateRuleStates
---@field initial CommunityCellStateRuleInitial
---@field transitions CommunityCellStateRuleTransition[] ordered 1..4 transition declarations
---@field restart CommunityCellStateRuleRestart

---@class CommunityCellStateRuleStates
---@field hidden CommunityCellStateHiddenPolicy

---@class CommunityCellStateHiddenPolicy
---@field digits "conceal"
---@field candidates "conceal"
---@field input "block"
---@field overlay "clip"

---@class CommunityCellStateRuleInitial
---@field hidden_cells integer[] zero-based cells that start hidden

---@class CommunityCellStateRuleTransition
---@field event "move.committed"
---@field condition CommunityCellStateRuleCondition
---@field effects CommunityCellStateRuleEffect[]

---@class CommunityCellStateRuleCondition
---@field placement "correct"|"any"

---@class CommunityCellStateRuleEffect
---@field operation "set_cell_state"
---@field state "visible"
---@field selector CommunityCellStateRuleSelector
---@field accumulation "union"

---@class CommunityCellStateRuleSelector
---@field origin "move.cell"
---@field expand CommunityCellStateRuleExpansion

---@class CommunityCellStateRuleExpansion
---@field type "radius"
---@field neighborhood "king"|"orthogonal"
---@field distance integer 0..2

---@class CommunityCellStateRuleRestart
---@field policy "initial"

---@return CommunityScriptBuilder Community Variant Script API V1 authoring builder
function CommunityVariantSdk.script() end

---@type CommunityVariantSdk
community_variant = community_variant

---@class CommunityScriptBuildResult
---Opaque Script V1 rule declaration. Return this value directly from main.lua.
local CommunityScriptBuildResult = {}
