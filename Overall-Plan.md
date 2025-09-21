# LibAT Project Planning Analysis

## Project Overview

Analyze the SpartanUI codebase to create a comprehensive project plan for extracting three core systems into a new standalone add-on called "Libs-AddonTools" (short code: LibAT).

## Systems to Extract

1. **Error Display/Handler System** - Extract error handling and display components
   - **Critical Loading Requirement**: Must load before all other systems (except shared UI components) to catch initialization errors within LibAT itself
   - **Database Independence**: Requires its own AceDB database object and saved variables, separate from other systems
   - **BugGrabber Integration**: Uses BugGrabber library to capture game API errors with custom processing and storage
2. **Profile Import/Export Process** - Extract and redesign for multi-addon support
3. **Extensible Logging System** - Extract current system AND use its UI as foundation for shared components

## Key Requirements Analysis

## Analysis Requirements for Each Phase

### For Phase 1 (Code Migration)

- Map all file dependencies for the three systems
- Identify shared utilities and libraries needed
- Document current addon structure and registration patterns
- Plan LibAT folder structure and organization

### For Phase 2 (Shared Components)

- Analyze current button implementations in Error Display and Logger
- Document the intentional texture stretching technique used for tab appearance
- Map single vs dual pane layout differences and requirements
- Create component interface specifications for reusable elements

### For Phase 3 (Error Display)

- Identify Error Display specific UI patterns and behaviors
- Document session management logic and data structures
- Plan component integration without losing functionality
- **CRITICAL**: Design independent database structure for error storage and settings
- **CRITICAL**: Ensure BugGrabber integration works with standalone error system
- **CRITICAL**: Plan loading order to initialize error capture before other LibAT systems

### For Phase 4 (Profile System)

- Research Ace3 database structure and namespace patterns
- Design left navigation tree structure for addon/namespace hierarchy
- Plan profile format that supports multi-addon configurations
- Design "All" option behavior for bulk namespace operations

### For Phase 5 (Logging Integration)

- Ensure logging system compatibility with shared components
- Plan integration testing strategy across all systems
- Document performance considerations and optimization opportunities

## Phased Implementation Strategy

### Phase 1: Code Migration Foundation

**Goal**: Establish LibAT addon structure with existing systems copied over

- Copy existing error display/handler system code to LibAT
- **CRITICAL**: Set up error display system with independent AceDB database and saved variables
- **CRITICAL**: Ensure BugGrabber dependency is properly declared and error capture initializes first
- Copy existing profile import/export process to LibAT
- Copy existing logging system to LibAT (this will serve as UI foundation)
- Establish basic addon structure and loading with proper initialization order
- **Loading Order**: Shared UI Components → Error Display → Profile System → Logger System
- Ensure all three systems function independently in new addon

### Phase 2: Shared Component Development

**Goal**: Extract logging UI into reusable component library

- **Button Components**: Extract button patterns from Error Display and Logger UI
- **Custom Tab System**: Extract and generalize the logging system's tab implementation
  - Analyze current 'All Errors', 'Current Session', 'Previous Session' tab implementation
  - Document the intentional texture stretching technique that creates the tab appearance
  - Create reusable tab component that maintains this visual design
  - Ensure tabs integrate properly with content areas
- **Window Base Types**: Extract and create two foundational window templates from logging system
  - **Single Pane Window**: Adapt logging UI for Error Display layout
  - **Dual Pane Window**: Extract current Logging window layout with left navigation
- All components should use native Blizzard UI elements and follow Auction House design language

### Phase 3: Error Display System Integration

**Goal**: Migrate Error Display to use shared components while maintaining critical functionality

- Replace existing UI elements with shared button and tab components
- Implement single pane window base for Error Display
- **CRITICAL**: Maintain independent database and saved variables structure
- **CRITICAL**: Preserve BugGrabber integration and error capture functionality
- **CRITICAL**: Ensure error system continues to load first and catch LibAT internal errors
- Ensure feature parity with original Error Display functionality
- Test session management (current/previous) with new tab system

### Phase 4: Profile Import/Export with Logging UI

**Goal**: Redesign Profile system using dual pane layout with namespace support

- Implement dual pane window base for Profile Import/Export
- **Left Navigation Design**:
  - Top level: Addon names
  - Expandable sub-levels: Individual namespaces (when addon uses them)
  - "All" option at top of each addon's namespace list for bulk operations
- Right pane: Import/Export interface using logging UI patterns
- Multi-addon profile format with namespace-aware structure
- Research and implement Ace3 database auto-detection if feasible

### Phase 5: Logging System Integration

**Goal**: Complete the shared component ecosystem

- Migrate logging system to use shared UI components
- Ensure logging maintains dual pane layout
- Integration testing across all three systems
- Performance optimization and cleanup

## Success Criteria

- Clean separation of systems with minimal coupling to SpartanUI
- Complete migration from STDUI to native Blizzard UI elements
- Consistent Auction House-style UI design language across all components
- Reusable component library that simplifies WoW addon UI development
- Robust multi-addon profile management system
- Enhanced error handling with improved user experience
- Well-documented, maintainable codebase following modern development practices

## Specific Focus Areas for Analysis

### UI Component Deep Dive

1. **Tab Design Technique**: How does the current texture stretching create the tab appearance?
2. **Button Standardization**: What button patterns exist across Error Display and Logger?
3. **Window Layout Differences**: What makes single vs dual pane layouts distinct?
4. **Auction House Pattern Adoption**: Which specific AH UI elements should be replicated?

### Technical Architecture

1. **STDUI Migration Path**: Which STDUI elements are currently used and what are their Blizzard UI equivalents?
2. **Component Reusability**: How can we design components to work across all three systems?
3. **Namespace Detection**: Is automatic Ace3 namespace detection technically feasible?
4. **Performance Considerations**: What are the memory and CPU implications of the component approach?

### System Integration

1. **Cross-System Dependencies**: What shared utilities exist between the three systems?
2. **Data Flow**: How do the systems currently share or isolate data?
3. **Event Handling**: What events do the systems currently handle and how can this be abstracted?

Please analyze the SpartanUI codebase thoroughly and provide detailed findings for each section, with specific code references and actionable recommendations.
