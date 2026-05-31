import xml.etree.ElementTree as ET

tree = ET.parse('/Users/thangto/Documents/gitui/gitui/App/MainWindowController.xib')
root = tree.getroot()

header_view = root.find(".//customView[@id='header-view']")
subviews = header_view.find('subviews')

# Add search field
search_field_str = '''
<searchField wantsLayer="YES" verticalHuggingPriority="750" textCompletion="NO" translatesAutoresizingMaskIntoConstraints="NO" id="file-search">
    <rect key="frame" x="16" y="8" width="200" height="22"/>
    <searchFieldCell key="cell" scrollable="YES" lineBreakMode="clipping" selectable="YES" editable="YES" borderStyle="bezel" placeholderString="Filter files..." usesSingleLineMode="YES" bezelStyle="round" id="file-search-cell">
        <font key="font" metaFont="system"/>
        <color key="textColor" name="controlTextColor" catalog="System" colorSpace="catalog"/>
        <color key="backgroundColor" name="textBackgroundColor" catalog="System" colorSpace="catalog"/>
    </searchFieldCell>
</searchField>
'''
search_field = ET.fromstring(search_field_str)
subviews.insert(0, search_field)

constraints = header_view.find('constraints')

c1 = ET.fromstring('<constraint firstItem="file-search" firstAttribute="centerY" secondItem="header-view" secondAttribute="centerY" id="fs-cy"/>')
c2 = ET.fromstring('<constraint firstItem="file-search" firstAttribute="leading" secondItem="header-view" secondAttribute="leading" constant="16" id="fs-l"/>')
c3 = ET.fromstring('<constraint firstItem="file-search" firstAttribute="width" constant="200" id="fs-w"/>')

constraints.append(c1)
constraints.append(c2)
constraints.append(c3)

# Add outlet
owner = root.find(".//customObject[@id='-2']/connections")
outlet = ET.fromstring('<outlet property="fileSearchField" destination="file-search" id="out-filesearch"/>')
owner.append(outlet)

tree.write('/Users/thangto/Documents/gitui/gitui/App/MainWindowController.xib', encoding='UTF-8', xml_declaration=True)
print("Added search field to XIB")
