import xml.etree.ElementTree as ET

xib_path = '/Users/golfzon/Documents/gitui/gitui/App/MainWindowController.xib'
tree = ET.parse(xib_path)
root = tree.getroot()

content_view = root.find(".//view[@id='se5-gp-TjO']")
content_subviews = content_view.find('subviews')
window_constraints = content_view.find('constraints')

if not root.find(".//customView[@id='titlebar-view']"):
    # Create titlebar-view
    titlebar_view = ET.Element('customView')
    titlebar_view.set('translatesAutoresizingMaskIntoConstraints', 'NO')
    titlebar_view.set('id', 'titlebar-view')
    titlebar_subviews = ET.SubElement(titlebar_view, 'subviews')
    titlebar_constraints = ET.SubElement(titlebar_view, 'constraints')
    
    # Let's create a container for the title items.
    center_container = ET.SubElement(titlebar_subviews, 'customView')
    center_container.set('translatesAutoresizingMaskIntoConstraints', 'NO')
    center_container.set('id', 'title-center-container')
    cc_subviews = ET.SubElement(center_container, 'subviews')
    cc_constraints = ET.SubElement(center_container, 'constraints')

    repo_title = root.find(".//textField[@id='repo-title']")
    branch_container = root.find(".//customView[@id='branch-container']")
    sync_status = root.find(".//textField[@id='sync-status']")
    
    old_parent = root.find(f".//textField[@id='repo-title']/..")
    if old_parent is not None: old_parent.remove(repo_title)
    
    old_parent = root.find(f".//customView[@id='branch-container']/..")
    if old_parent is not None: old_parent.remove(branch_container)
        
    old_parent = root.find(f".//textField[@id='sync-status']/..")
    if old_parent is not None: old_parent.remove(sync_status)
        
    cc_subviews.append(repo_title)
    cc_subviews.append(branch_container)
    cc_subviews.append(sync_status)
    
    ET.SubElement(titlebar_constraints, 'constraint', {'firstAttribute': 'height', 'constant': '38', 'id': 'tb-title-h'})
    ET.SubElement(titlebar_constraints, 'constraint', {'firstItem': 'title-center-container', 'firstAttribute': 'centerX', 'secondItem': 'titlebar-view', 'secondAttribute': 'centerX', 'id': 'tcc-cx'})
    ET.SubElement(titlebar_constraints, 'constraint', {'firstItem': 'title-center-container', 'firstAttribute': 'centerY', 'secondItem': 'titlebar-view', 'secondAttribute': 'centerY', 'id': 'tcc-cy'})
    
    ET.SubElement(cc_constraints, 'constraint', {'firstItem': 'repo-title', 'firstAttribute': 'leading', 'secondItem': 'title-center-container', 'secondAttribute': 'leading', 'id': 'c-rt-l'})
    ET.SubElement(cc_constraints, 'constraint', {'firstItem': 'repo-title', 'firstAttribute': 'centerY', 'secondItem': 'title-center-container', 'secondAttribute': 'centerY', 'id': 'c-rt-cy'})
    
    ET.SubElement(cc_constraints, 'constraint', {'firstItem': 'branch-container', 'firstAttribute': 'leading', 'secondItem': 'repo-title', 'secondAttribute': 'trailing', 'constant': '8', 'id': 'c-bc-l'})
    ET.SubElement(cc_constraints, 'constraint', {'firstItem': 'branch-container', 'firstAttribute': 'centerY', 'secondItem': 'title-center-container', 'secondAttribute': 'centerY', 'id': 'c-bc-cy'})
    
    ET.SubElement(cc_constraints, 'constraint', {'firstItem': 'sync-status', 'firstAttribute': 'leading', 'secondItem': 'branch-container', 'secondAttribute': 'trailing', 'constant': '8', 'id': 'c-ss-l'})
    ET.SubElement(cc_constraints, 'constraint', {'firstItem': 'sync-status', 'firstAttribute': 'centerY', 'secondItem': 'title-center-container', 'secondAttribute': 'centerY', 'id': 'c-ss-cy'})
    ET.SubElement(cc_constraints, 'constraint', {'firstItem': 'title-center-container', 'firstAttribute': 'trailing', 'secondItem': 'sync-status', 'secondAttribute': 'trailing', 'id': 'c-ss-r'})
    
    content_subviews.insert(0, titlebar_view)
    
    ET.SubElement(window_constraints, 'constraint', {'firstItem': 'titlebar-view', 'firstAttribute': 'leading', 'secondItem': 'se5-gp-TjO', 'secondAttribute': 'leading', 'id': 'tbv-l'})
    ET.SubElement(window_constraints, 'constraint', {'firstItem': 'titlebar-view', 'firstAttribute': 'trailing', 'secondItem': 'se5-gp-TjO', 'secondAttribute': 'trailing', 'id': 'tbv-r'})
    ET.SubElement(window_constraints, 'constraint', {'firstItem': 'titlebar-view', 'firstAttribute': 'top', 'secondItem': 'se5-gp-TjO', 'secondAttribute': 'top', 'id': 'tbv-t'})
    
    for c in window_constraints:
        if c.get('firstItem') == 'toolbar-view' and c.get('firstAttribute') == 'top':
            c.set('secondItem', 'titlebar-view')
            c.set('secondAttribute', 'bottom')
            if 'constant' in c.attrib:
                del c.attrib['constant']

    for constraints_node in root.findall('.//constraints'):
        to_remove = []
        for c in constraints_node:
            first = c.get('firstItem')
            second = c.get('secondItem')
            if (first in ['repo-title', 'branch-container', 'sync-status'] and first != second) or \
               (second in ['repo-title', 'branch-container', 'sync-status'] and first != second):
                if c.get('id') not in ['c-rt-l', 'c-rt-cy', 'c-bc-l', 'c-bc-cy', 'c-ss-l', 'c-ss-cy', 'c-ss-r']:
                    to_remove.append(c)
        for c in to_remove:
            constraints_node.remove(c)

    tree.write(xib_path, encoding='UTF-8', xml_declaration=True)
    print("XIB updated successfully")
else:
    print("titlebar-view already exists")
