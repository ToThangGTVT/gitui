import xml.etree.ElementTree as ET

tree = ET.parse('/Users/thangto/Documents/gitui/gitui/App/MainWindowController.xib')
root = tree.getroot()

# Find se5-gp-TjO subviews
content_view = root.find(".//view[@id='se5-gp-TjO']")
content_subviews = content_view.find('subviews')

# Find header-view
header_view = root.find(".//customView[@id='header-view']")
header_subviews = header_view.find('subviews')
header_constraints = header_view.find('constraints')

# Extract elements to move
repo_title = header_subviews.find(".//textField[@id='repo-title']")
branch_container = header_subviews.find(".//customView[@id='branch-container']")
sync_status = header_subviews.find(".//textField[@id='sync-status']")

header_subviews.remove(repo_title)
header_subviews.remove(branch_container)
header_subviews.remove(sync_status)

# Create titlebar-view
titlebar_view = ET.Element('customView')
titlebar_view.set('translatesAutoresizingMaskIntoConstraints', 'NO')
titlebar_view.set('id', 'titlebar-view')

titlebar_rect = ET.SubElement(titlebar_view, 'rect')
titlebar_rect.set('key', 'frame')
titlebar_rect.set('x', '0.0')
titlebar_rect.set('y', '662')
titlebar_rect.set('width', '1000')
titlebar_rect.set('height', '38')

titlebar_subviews = ET.SubElement(titlebar_view, 'subviews')
titlebar_subviews.append(repo_title)
titlebar_subviews.append(branch_container)
titlebar_subviews.append(sync_status)

titlebar_constraints = ET.SubElement(titlebar_view, 'constraints')
ET.SubElement(titlebar_constraints, 'constraint', {'firstAttribute': 'height', 'constant': '38', 'id': 'tb-title-h'})

ET.SubElement(titlebar_constraints, 'constraint', {'firstItem': 'repo-title', 'firstAttribute': 'centerY', 'secondItem': 'titlebar-view', 'secondAttribute': 'centerY', 'id': 'ttv-c1'})
ET.SubElement(titlebar_constraints, 'constraint', {'firstItem': 'repo-title', 'firstAttribute': 'leading', 'secondItem': 'titlebar-view', 'secondAttribute': 'leading', 'constant': '80', 'id': 'ttv-c2'})

ET.SubElement(titlebar_constraints, 'constraint', {'firstItem': 'branch-container', 'firstAttribute': 'centerY', 'secondItem': 'titlebar-view', 'secondAttribute': 'centerY', 'id': 'ttv-c3'})
ET.SubElement(titlebar_constraints, 'constraint', {'firstItem': 'branch-container', 'firstAttribute': 'leading', 'secondItem': 'repo-title', 'secondAttribute': 'trailing', 'constant': '16', 'id': 'ttv-c4'})

ET.SubElement(titlebar_constraints, 'constraint', {'firstItem': 'sync-status', 'firstAttribute': 'centerY', 'secondItem': 'titlebar-view', 'secondAttribute': 'centerY', 'id': 'ttv-c5'})
ET.SubElement(titlebar_constraints, 'constraint', {'firstItem': 'sync-status', 'firstAttribute': 'leading', 'secondItem': 'branch-container', 'secondAttribute': 'trailing', 'constant': '16', 'id': 'ttv-c6'})

# Insert titlebar-view at the beginning of window content view subviews
content_subviews.insert(0, titlebar_view)

# Remove old constraints from header-view
to_remove = []
for c in header_constraints:
    if c.get('firstItem') in ['repo-title', 'branch-container', 'sync-status'] or c.get('secondItem') in ['repo-title', 'branch-container', 'sync-status']:
        to_remove.append(c)
for c in to_remove:
    header_constraints.remove(c)

# Change header-view height to 38 so seg-control fits nicely
for c in header_constraints:
    if c.get('id') == 'header-h':
        c.set('constant', '38')

# Update window content view constraints
window_constraints = content_view.find('constraints')

# Add titlebar-view constraints
ET.SubElement(window_constraints, 'constraint', {'firstItem': 'titlebar-view', 'firstAttribute': 'leading', 'secondItem': 'se5-gp-TjO', 'secondAttribute': 'leading', 'id': 'tbv-l'})
ET.SubElement(window_constraints, 'constraint', {'firstItem': 'titlebar-view', 'firstAttribute': 'trailing', 'secondItem': 'se5-gp-TjO', 'secondAttribute': 'trailing', 'id': 'tbv-r'})
ET.SubElement(window_constraints, 'constraint', {'firstItem': 'titlebar-view', 'firstAttribute': 'top', 'secondItem': 'se5-gp-TjO', 'secondAttribute': 'top', 'id': 'tbv-t'})

# Update toolbar-view top constraint
for c in window_constraints:
    if c.get('id') == 'tb-t':
        c.set('firstItem', 'toolbar-view')
        c.set('firstAttribute', 'top')
        c.set('secondItem', 'titlebar-view')
        c.set('secondAttribute', 'bottom')
        if 'constant' in c.attrib:
            del c.attrib['constant']

tree.write('/Users/thangto/Documents/gitui/gitui/App/MainWindowController.xib', encoding='UTF-8', xml_declaration=True)
print("XIB updated successfully")
